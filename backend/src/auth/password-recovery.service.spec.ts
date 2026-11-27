import { BadRequestException, HttpException, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PasswordRecoveryService } from './password-recovery.service';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { createHash } from 'node:crypto';

describe('password recovery security', () => {
  const row: any = {};
  const db: any = {
    user: { findFirst: jest.fn().mockResolvedValue({ id: 7 }), update: jest.fn() },
    passwordRecovery: { findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
    refreshSession: { updateMany: jest.fn() },
    $queryRaw: jest.fn(),
  };
  db.$transaction = jest.fn((fn) => fn(db));
  const service = new PasswordRecoveryService(db as PrismaService, { get: jest.fn() } as unknown as ConfigService);
  beforeEach(async () => {
    jest.clearAllMocks();
    Object.assign(row, { codeHash: await bcrypt.hash('123456', 4), expiresAt: new Date(Date.now() + 60000), attempts: 0, resetTokenHash: null });
    db.passwordRecovery.findUnique.mockResolvedValue(row);
  });
  it('fails closed if SMTP is not configured', async () => {
    await expect(service.request('test@example.com')).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
  it('requires a recoverable local credential at every stage and gives a generic request response', async () => {
    const smtp = { SMTP_HOST: 'smtp.example.invalid', SMTP_PORT: '587', SMTP_USER: 'test', SMTP_PASSWORD: 'test', SMTP_FROM: 'test@example.invalid' };
    const configured = new PasswordRecoveryService(db, { get: (key: keyof typeof smtp) => smtp[key] } as ConfigService);
    db.user.findFirst.mockResolvedValueOnce(null).mockResolvedValueOnce(null).mockResolvedValueOnce(null);
    const email = 'player@example.invalid';
    await expect(configured.request(email)).resolves.toEqual({ message: 'If the account exists, a verification code has been sent.' });
    await expect(configured.verify(email, '000000')).rejects.toBeInstanceOf(BadRequestException);
    await expect(configured.reset(email, 'invalid', 'New-password1!')).rejects.toBeInstanceOf(BadRequestException);
    for (const [query] of db.user.findFirst.mock.calls) {
      expect(query.where.OR).toEqual([{ googleIdentity: null }, { googleIdentity: { is: { localPasswordConfirmed: true } } }]);
    }
    expect(db.$transaction).not.toHaveBeenCalled();
  });
  it('rejects a consumed code even while its original expiry is in the future', async () => {
    row.resetTokenHash = 'already-verified';
    await expect(service.verify('test@example.com', '123456')).rejects.toBeInstanceOf(BadRequestException);
    expect(db.passwordRecovery.update).not.toHaveBeenCalled();
  });
  it('increments attempts on invalid code and does not issue a reset token', async () => {
    await expect(service.verify('test@example.com', '111111')).rejects.toBeInstanceOf(BadRequestException);
    expect(db.passwordRecovery.update).toHaveBeenCalledWith(expect.objectContaining({ data: { attempts: { increment: 1 } } }));
  });
  it('rejects expired and exhausted verification codes', async () => {
    row.attempts = 5;
    await expect(service.verify('test@example.com', '123456')).rejects.toBeInstanceOf(BadRequestException);
    row.attempts = 0; row.expiresAt = new Date(0);
    await expect(service.verify('test@example.com', '123456')).rejects.toBeInstanceOf(BadRequestException);
  });
  it('issues a reset token for a valid code', async () => {
    const result = await service.verify('test@example.com', '123456');
    expect(result.resetToken).toMatch(/^[0-9a-f]{64}$/);
    expect(db.passwordRecovery.update).toHaveBeenCalledTimes(1);
  });
  it('changes password, revokes sessions and consumes token only when valid', async () => {
    const token = 'a'.repeat(64);
    row.resetTokenHash = createHash('sha256').update(token).digest('hex');
    row.resetExpiresAt = new Date(Date.now() + 60000);
    await service.reset('test@example.com', token, 'New-password1!');
    expect(db.user.update).toHaveBeenCalledTimes(1);
    expect(db.refreshSession.updateMany).toHaveBeenCalledTimes(1);
    expect(db.passwordRecovery.delete).toHaveBeenCalledTimes(1);
  });
  it('rejects an invalid reset token without changing the user', async () => {
    row.resetTokenHash = 'invalid'; row.resetExpiresAt = new Date(Date.now() + 60000);
    await expect(service.reset('test@example.com', 'a'.repeat(64), 'New-password1!')).rejects.toBeInstanceOf(BadRequestException);
    expect(db.user.update).not.toHaveBeenCalled();
  });
  it('limits repeated recovery requests per IP', () => {
    for (let i = 0; i < 5; i++) service.limit('test-ip', 'request');
    expect(() => service.limit('test-ip', 'request')).toThrow(HttpException);
  });
});
