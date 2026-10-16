import { BadRequestException, Controller, ForbiddenException, Get, NotFoundException, Param, ParseIntPipe, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { Role } from '../auth/roles.enum';
import { UsersService } from './users.service';

@ApiTags('users')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  @Roles(Role.ADMIN)
  async findAll() {
    return this.usersService.findAllForApi();
  }

  @Get(':id')
  async findOne(
    @Param('id', ParseIntPipe) id: number,
    @Req() req: { user: { sub: number; role: string } },
  ) {
    if (!Number.isInteger(id) || id < 1 || id > 2147483647) {
      throw new BadRequestException('User ID phải là số nguyên từ 1 đến 2147483647');
    }
    if (req.user.role !== Role.ADMIN && req.user.sub !== id) {
      throw new ForbiddenException('Bạn không có quyền xem người dùng này');
    }
    const record = await this.usersService.findByIdForApi(id);
    if (!record) {
      throw new NotFoundException(`User ${id} not found`);
    }
    return record;
  }
}
