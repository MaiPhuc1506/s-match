import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { AuthTokensService } from './auth-tokens.service';
import { Prisma, RoleName } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { PrismaService } from '../prisma/prisma.service';

describe('Register (Prisma mock)', () => {
  const validInput = {
    email: 'player@example.test',
    password: 'Register-test-123!',
    fullName: 'Test Player',
    phoneNumber: '0900000000',
  };
  let prisma: { user: { findFirst: jest.Mock; create: jest.Mock } };
  let service: AuthService;
  let controller: AuthController;
  let pipe: ValidationPipe;

  beforeEach(() => {
    prisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockImplementation(async ({ data }) => ({
          id: 42,
          email: data.email,
          fullName: data.fullName,
        })),
      },
    };
    service = new AuthService(
      prisma as unknown as PrismaService,
      {} as AuthTokensService,
    );
    controller = new AuthController(service);
    // Exercise the same validation boundary as main.ts, without starting Nest or a DB.
    pipe = new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    });
  });

  async function register(input: Record<string, unknown>) {
    const dto = await pipe.transform(input, {
      type: 'body',
      metatype: RegisterDto,
    });
    return controller.register(dto);
  }

  it('creates a persistent PLAYER with normalized email and the existing response contract', async () => {
    const response = await register({
      ...validInput,
      email: '  PLAYER@Example.Test  ',
      fullName: '  Test Player  ',
    });

    expect(prisma.user.findFirst).toHaveBeenCalledWith({
      where: { email: { equals: validInput.email, mode: 'insensitive' } },
      select: { id: true },
    });
    const { data, select } = prisma.user.create.mock.calls[0][0];
    expect(data).toMatchObject({
      email: validInput.email,
      fullName: validInput.fullName,
      phone: validInput.phoneNumber,
      role: {
        connectOrCreate: {
          where: { name: RoleName.PLAYER },
          create: { name: RoleName.PLAYER },
        },
      },
    });
    expect(select).toEqual({ id: true, email: true, fullName: true });
    expect(response).toEqual({
      message: 'Đăng ký thành công',
      data: {
        id: 42,
        email: validInput.email,
        fullName: validInput.fullName,
        role: 'Player',
      },
    });
  });

  it('hashes the password with bcrypt and does not expose plaintext or hash', async () => {
    const response = await register(validInput);
    const storedHash = prisma.user.create.mock.calls[0][0].data.password;
    expect(storedHash).not.toBe(validInput.password);
    expect(await bcrypt.compare(validInput.password, storedHash)).toBe(true);
    expect(bcrypt.getRounds(storedHash)).toBe(10);
    expect(response.data).not.toHaveProperty('password');
    expect(JSON.stringify(response)).not.toContain(validInput.password);
    expect(JSON.stringify(response)).not.toContain(storedHash);
  });

  it('allows the optional phoneNumber to be omitted', async () => {
    const { phoneNumber: _phoneNumber, ...input } = validInput;
    await register(input);
    expect(prisma.user.create.mock.calls[0][0].data.phone).toBeUndefined();
  });

  it('rejects an existing email before creating a user', async () => {
    prisma.user.findFirst.mockResolvedValue({ id: 7 });
    await expect(register({ ...validInput, email: 'PLAYER@EXAMPLE.TEST' }))
      .rejects.toThrow(BadRequestException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it.each([{ target: ['email'] }, { target: 'User_email_key' }])('handles an email unique-constraint race (%j)', async ({ target }) => {
    prisma.user.create.mockRejectedValue(new Prisma.PrismaClientKnownRequestError(
      'Unique constraint failed',
      { code: 'P2002', clientVersion: '6.19.3', meta: { target } },
    ));
    await expect(register(validInput)).rejects.toThrow(BadRequestException);
  });

  it('does not misreport an unrelated Prisma unique error as duplicate email', async () => {
    const error = new Prisma.PrismaClientKnownRequestError('Unique constraint failed', {
      code: 'P2002', clientVersion: '6.19.3', meta: { target: ['name'] },
    });
    prisma.user.create.mockRejectedValue(error);
    await expect(register(validInput)).rejects.toBe(error);
  });

  it.each([
    ['invalid email', { email: 'invalid' }],
    ['missing email', { email: undefined }],
    ['short password', { password: '1' }],
    ['non-string password', { password: 123456 }],
    ['missing fullName', { fullName: undefined }],
    ['blank fullName', { fullName: '   ' }],
    ['non-string phoneNumber', { phoneNumber: 900000000 }],
  ])('rejects %s without accessing Prisma', async (_description, invalidFields) => {
    await expect(register({ ...validInput, ...invalidFields }))
      .rejects.toThrow(BadRequestException);
    expect(prisma.user.findFirst).not.toHaveBeenCalled();
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it.each([
    { role: 'ADMIN' },
    { role: 'COURT_OWNER' },
    { roleId: 1 },
    { role: { connect: { name: 'ADMIN' } } },
  ])('rejects client privilege fields (%j)', async (privilegeFields) => {
    await expect(register({ ...validInput, ...privilegeFields }))
      .rejects.toThrow(BadRequestException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('still assigns PLAYER if an internal caller bypasses DTO validation', async () => {
    await service.register({ ...validInput, role: 'ADMIN', roleId: 1 } as RegisterDto);
    expect(prisma.user.create.mock.calls[0][0].data.role).toEqual({
      connectOrCreate: {
        where: { name: RoleName.PLAYER },
        create: { name: RoleName.PLAYER },
      },
    });
    expect(prisma.user.create.mock.calls[0][0].data).not.toHaveProperty('roleId');
  });
});
