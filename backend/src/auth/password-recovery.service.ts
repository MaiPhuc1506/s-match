import { BadRequestException, HttpException, Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { createHash, randomBytes, randomInt } from 'node:crypto';
import * as bcrypt from 'bcrypt';
import * as nodemailer from 'nodemailer';

const generic = { message: 'If the account exists, a verification code has been sent.' };
const hash = (value: string) => createHash('sha256').update(value).digest('hex');

@Injectable()
export class PasswordRecoveryService {
  private readonly logger = new Logger(PasswordRecoveryService.name);
  private readonly limits = new Map<string, { count: number; until: number }>();
  constructor(private readonly prisma: PrismaService, private readonly config: ConfigService) {}

  limit(ip: string, action: string) {
    const now = Date.now();
    for (const [key, value] of this.limits) if (value.until <= now) this.limits.delete(key);
    const key = `${ip}:${action}`;
    const entry = this.limits.get(key) ?? { count: 0, until: now + 600000 };
    if (entry.count >= (action === 'request' ? 5 : 20)) throw new HttpException('Too many attempts. Please try again later.', 429);
    entry.count++;
    this.limits.set(key, entry);
  }

  private recoveryAccount(email: string) {
    return this.prisma.user.findFirst({
      where: {
        email: { equals: email.trim().toLowerCase(), mode: 'insensitive' },
        OR: [{ googleIdentity: null }, { googleIdentity: { is: { localPasswordConfirmed: true } } }],
      },
      select: { id: true, email: true },
    });
  }

  async request(email: string) {
    const host = this.config.get<string>('SMTP_HOST');
    const port = Number(this.config.get<string>('SMTP_PORT'));
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASSWORD');
    const from = this.config.get<string>('SMTP_FROM');
    if (!host || !Number.isInteger(port) || port < 1 || port > 65535 || !user || !pass || !from) {
      throw new ServiceUnavailableException('Password recovery email is not configured.');
    }
    const account = await this.recoveryAccount(email);
    if (!account) return generic;
    const code = randomInt(0, 1000000).toString().padStart(6, '0');
    const codeHash = await bcrypt.hash(code, 12);
    const now = new Date();
    const created = await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT "id" FROM "User" WHERE "id" = ${account.id} FOR UPDATE`;
      const existing = await tx.passwordRecovery.findUnique({ where: { userId: account.id } });
      if (existing && now.getTime() - existing.lastSentAt.getTime() < 60000) return false;
      await tx.passwordRecovery.upsert({ where: { userId: account.id }, create: { userId: account.id, codeHash, expiresAt: new Date(now.getTime() + 600000), lastSentAt: now }, update: { codeHash, expiresAt: new Date(now.getTime() + 600000), lastSentAt: now, attempts: 0, resetTokenHash: null, resetExpiresAt: null } });
      return true;
    });
    if (!created) return generic;
    const transport = nodemailer.createTransport({ host, port, secure: port === 465, requireTLS: port !== 465, auth: { user, pass }, connectionTimeout: 10000, socketTimeout: 10000 });
    try { await transport.sendMail({ from, to: account.email, subject: 'S-Match password recovery', text: `Your S-Match verification code is ${code}. It expires in 10 minutes. If you did not request this, ignore this email.` }); } catch { this.logger.error('Password recovery email delivery failed'); } finally { transport.close(); }
    return generic;
  }

  async verify(email: string, code: string) {
    const account = await this.recoveryAccount(email);
    if (!account) throw new BadRequestException('Invalid or expired verification code.');
    const result = await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT "userId" FROM "PasswordRecovery" WHERE "userId" = ${account.id} FOR UPDATE`;
      const row = await tx.passwordRecovery.findUnique({ where: { userId: account.id } });
      if (!row || row.expiresAt <= new Date() || row.attempts >= 5 || row.resetTokenHash) return null;
      if (!await bcrypt.compare(code, row.codeHash)) {
        await tx.passwordRecovery.update({ where: { userId: account.id }, data: { attempts: { increment: 1 } } });
        return null;
      }
      const token = randomBytes(32).toString('hex');
      await tx.passwordRecovery.update({ where: { userId: account.id }, data: { resetTokenHash: hash(token), resetExpiresAt: new Date(Date.now() + 300000) } });
      return token;
    });
    if (!result) throw new BadRequestException('Invalid or expired verification code.');
    return { resetToken: result };
  }

  async reset(email: string, token: string, password: string) {
    if (Buffer.byteLength(password, 'utf8') > 72) throw new BadRequestException('Password is too long.');
    const account = await this.recoveryAccount(email);
    if (!account) throw new BadRequestException('Invalid or expired reset request.');
    const passwordHash = await bcrypt.hash(password, 12);
    const changed = await this.prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT "userId" FROM "PasswordRecovery" WHERE "userId" = ${account.id} FOR UPDATE`;
      const row = await tx.passwordRecovery.findUnique({ where: { userId: account.id } });
      if (!row?.resetTokenHash || !row.resetExpiresAt || row.resetExpiresAt <= new Date() || row.resetTokenHash !== hash(token)) return false;
      await tx.user.update({ where: { id: account.id }, data: { password: passwordHash } });
      await tx.refreshSession.updateMany({ where: { userId: account.id, revokedAt: null }, data: { revokedAt: new Date() } });
      await tx.passwordRecovery.delete({ where: { userId: account.id } });
      return true;
    });
    if (!changed) throw new BadRequestException('Invalid or expired reset request.');
    return { message: 'Password updated. Please sign in again.' };
  }
}
