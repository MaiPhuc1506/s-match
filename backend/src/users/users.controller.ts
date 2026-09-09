import { Controller, Get, NotFoundException, Param, ParseIntPipe } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { UsersService } from './users.service';

// SMM-8 — User Database & Backend Connection.
// No auth guard exists yet (that's SMM-6), so these endpoints are intentionally
// unprotected and only meant to prove the User table + DB connection work end to end.
// Once Auth (SMM-6) lands, replace/extend this with a guarded `GET /users/me`.
@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  async findAll() {
    const users = await this.usersService.findAll();
    return users.map(({ password: _password, ...safe }) => safe);
  }

  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number) {
    const record = await this.usersService.findById(id);
    if (!record) {
      throw new NotFoundException(`User ${id} not found`);
    }
    const { password: _password, ...safe } = record;
    return safe;
  }
}
