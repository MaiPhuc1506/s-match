import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { RatingsService } from './ratings.service';
import { CreateRatingDto, ListRatingsQueryDto, UpdateRatingDto } from './dto/rating.dto';

@ApiTags('Community Rating')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.PLAYER)
@Controller('ratings')
export class RatingsController {
  constructor(private readonly ratingsService: RatingsService) {}

  private extractUserId(req: any): number {
    const user = req.user || req.raw?.user;
    return Number(user?.id ?? user?.sub ?? user?.userId);
  }

  @Post()
  @ApiOperation({ summary: 'Đánh giá một người chơi cùng trận sau khi trận kết thúc' })
  @ApiResponse({ status: 201, description: 'Đã tạo đánh giá.' })
  @ApiResponse({ status: 400, description: 'Trận chưa kết thúc / đã huỷ / quá hạn / tự đánh giá / người được đánh giá không thuộc trận.' })
  @ApiResponse({ status: 403, description: 'Bạn không tham gia trận này.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy trận đấu.' })
  @ApiResponse({ status: 409, description: 'Đã đánh giá người này trong trận này.' })
  create(@Request() req: any, @Body() dto: CreateRatingDto) {
    return this.ratingsService.create(this.extractUserId(req), dto);
  }

  @Get('pending')
  @ApiOperation({ summary: 'Các trận đã kết thúc mà tôi còn người chơi chưa đánh giá' })
  @ApiResponse({ status: 200, description: 'Danh sách [{ matchId, title, startTime, endTime, players }].' })
  pending(@Request() req: any) {
    return this.ratingsService.listPending(this.extractUserId(req));
  }

  @Get('given')
  @ApiOperation({ summary: 'Các đánh giá tôi đã gửi (mới nhất trước, có phân trang)' })
  @ApiResponse({ status: 200, description: '{ items, page, limit, total, totalPages }' })
  given(@Request() req: any, @Query() query: ListRatingsQueryDto) {
    return this.ratingsService.listGiven(this.extractUserId(req), query);
  }

  @Get('users/:userId/summary')
  @ApiOperation({ summary: 'Tổng hợp đánh giá cộng đồng của một người chơi (điểm TB, phân bố, điểm uy tín)' })
  @ApiResponse({ status: 200, description: 'Tổng hợp đánh giá.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy người dùng.' })
  summary(@Param('userId', ParseIntPipe) userId: number) {
    return this.ratingsService.getSummary(userId);
  }

  @Get('users/:userId/history')
  @ApiOperation({ summary: 'Lịch sử Community Rating của một người chơi (snapshot sau mỗi đánh giá)' })
  @ApiResponse({ status: 200, description: '{ items, page, limit, total, totalPages }' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy người dùng.' })
  history(@Param('userId', ParseIntPipe) userId: number, @Query() query: ListRatingsQueryDto) {
    return this.ratingsService.listHistory(userId, query);
  }

  @Get('users/:userId')
  @ApiOperation({ summary: 'Các đánh giá một người chơi đã nhận (mới nhất trước, có phân trang)' })
  @ApiResponse({ status: 200, description: '{ items, page, limit, total, totalPages }' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy người dùng.' })
  received(@Param('userId', ParseIntPipe) userId: number, @Query() query: ListRatingsQueryDto) {
    return this.ratingsService.listReceived(userId, query);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Sửa đánh giá của tôi (trong 24 giờ sau khi tạo)' })
  @ApiResponse({ status: 200, description: 'Đã cập nhật.' })
  @ApiResponse({ status: 400, description: 'Hết thời hạn sửa hoặc không có trường nào để cập nhật.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy đánh giá (hoặc không phải của bạn).' })
  update(
    @Request() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateRatingDto,
  ) {
    return this.ratingsService.update(this.extractUserId(req), id, dto);
  }
}
