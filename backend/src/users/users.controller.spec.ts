import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('UsersController', () => {
  const record = { id: 8, fullName: 'Test Player', role: { name: Role.PLAYER } };
  let service: { findAllForApi: jest.Mock; findByIdForApi: jest.Mock };
  let controller: UsersController;

  beforeEach(() => {
    service = {
      findAllForApi: jest.fn().mockResolvedValue([record]),
      findByIdForApi: jest.fn().mockResolvedValue(record),
    };
    controller = new UsersController(service as unknown as UsersService);
  });

  it('protects both routes and restricts the list to ADMIN', () => {
    expect(Reflect.getMetadata('__guards__', UsersController)).toContain(RolesGuard);
    const reflector = new Reflector();
    expect(reflector.get(ROLES_KEY, controller.findAll)).toEqual([Role.ADMIN]);
    expect(reflector.get(ROLES_KEY, controller.findOne)).toBeUndefined();
  });

  it('returns an array for the ADMIN list route', async () => {
    await expect(controller.findAll()).resolves.toEqual([record]);
  });

  it.each([Role.PLAYER, Role.OWNER, Role.ADMIN])('allows %s to read itself', async (role) => {
    await expect(controller.findOne(8, { user: { sub: 8, role } })).resolves.toEqual(record);
    expect(service.findByIdForApi).toHaveBeenCalledWith(8);
  });

  it.each([Role.PLAYER, Role.OWNER])('blocks %s cross-user reads before querying existence', async (role) => {
    service.findByIdForApi.mockResolvedValue(null);
    await expect(controller.findOne(999, { user: { sub: 8, role } })).rejects.toBeInstanceOf(ForbiddenException);
    expect(service.findByIdForApi).not.toHaveBeenCalled();
  });

  it('allows ADMIN to read another user', async () => {
    await expect(controller.findOne(8, { user: { sub: 1, role: Role.ADMIN } })).resolves.toEqual(record);
  });

  it('returns 404 when ADMIN requests a missing user', async () => {
    service.findByIdForApi.mockResolvedValue(null);
    await expect(controller.findOne(999, { user: { sub: 1, role: Role.ADMIN } })).rejects.toBeInstanceOf(NotFoundException);
  });

  it.each([0, -1, 1.5, 2147483648, Number.MAX_SAFE_INTEGER, NaN, Infinity])(
    'rejects invalid numeric ID %s before querying or checking ownership', async (id) => {
      for (const role of [Role.PLAYER, Role.OWNER, Role.ADMIN]) {
        await expect(controller.findOne(id, { user: { sub: 8, role } })).rejects.toBeInstanceOf(BadRequestException);
      }
      expect(service.findByIdForApi).not.toHaveBeenCalled();
    },
  );

  it.each([1, 2147483647])('accepts the valid ID boundary %s', async (id) => {
    await controller.findOne(id, { user: { sub: 8, role: Role.ADMIN } });
    expect(service.findByIdForApi).toHaveBeenCalledWith(id);
  });
});
