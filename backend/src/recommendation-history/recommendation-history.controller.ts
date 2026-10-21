import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { RecommendationHistoryService } from './recommendation-history.service';
import { ListHistoryQueryDto, UpdateOutcomeDto } from './dto/recommendation-history.dto';

@ApiTags('Recommendation History')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.PLAYER)
@Controller('recommendations/history')
export class RecommendationHistoryController {
  constructor(private readonly historyService: RecommendationHistoryService) {}

  private extractUserId(req: any): number {
    const user = req.user || req.raw?.user;
    return Number(user?.id ?? user?.sub ?? user?.userId);
  }

  @Get()
  @ApiOperation({ summary: 'Xem lịch sử các lần được gợi ý đối thủ (mới nhất trước, có phân trang)' })
  @ApiResponse({ status: 200, description: '{ items, page, limit, total, totalPages }' })
  list(@Request() req: any, @Query() query: ListHistoryQueryDto) {
    return this.historyService.listMine(this.extractUserId(req), query);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Thống kê gợi ý: tỉ lệ mời, tỉ lệ chấp nhận, điểm tương thích trung bình' })
  @ApiResponse({ status: 200, description: 'Thống kê gợi ý của tôi.' })
  stats(@Request() req: any) {
    return this.historyService.getStats(this.extractUserId(req));
  }

  @Get(':id')
  @ApiOperation({ summary: 'Chi tiết một phiên gợi ý, kèm danh sách Top-K theo thứ hạng' })
  @ApiResponse({ status: 200, description: 'Chi tiết phiên gợi ý.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy phiên (hoặc không phải của bạn).' })
  findOne(@Request() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.historyService.findOneOrThrow(this.extractUserId(req), id);
  }

  @Patch(':sessionId/results/:resultId')
  @ApiOperation({ summary: 'Cập nhật kết quả của một gợi ý (đã mời / đã chấp nhận / bỏ qua)' })
  @ApiResponse({ status: 200, description: 'Đã cập nhật.' })
  @ApiResponse({ status: 400, description: 'Chuyển trạng thái không hợp lệ.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy kết quả gợi ý.' })
  updateOutcome(
    @Request() req: any,
    @Param('sessionId', ParseIntPipe) sessionId: number,
    @Param('resultId', ParseIntPipe) resultId: number,
    @Body() dto: UpdateOutcomeDto,
  ) {
    return this.historyService.updateOutcome(this.extractUserId(req), sessionId, resultId, dto.outcome);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Xoá một phiên trong lịch sử gợi ý của tôi' })
  @ApiResponse({ status: 200, description: 'Đã xoá.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy phiên.' })
  remove(@Request() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.historyService.remove(this.extractUserId(req), id);
  }
}
