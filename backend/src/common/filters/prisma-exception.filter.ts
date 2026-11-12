import {
  ArgumentsHost,
  BadRequestException,
  Catch,
  ConflictException,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  NotFoundException,
} from '@nestjs/common';
import { Response } from 'express';
import { Prisma } from '@prisma/client';

@Catch(Prisma.PrismaClientKnownRequestError)
export class PrismaExceptionFilter implements ExceptionFilter {
  catch(exception: Prisma.PrismaClientKnownRequestError, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let httpException: HttpException;

    switch (exception.code) {
      case 'P2002':
        httpException = new ConflictException('Dữ liệu đã tồn tại (xung đột khóa duy nhất)');
        break;
      case 'P2025':
        httpException = new NotFoundException('Không tìm thấy bản ghi yêu cầu');
        break;
      case 'P2003':
        httpException = new BadRequestException('Dữ liệu liên kết không hợp lệ (vi phạm khóa ngoại)');
        break;
      default:
        return response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
          statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
          message: 'Lỗi cơ sở dữ liệu nội bộ',
          error: 'Internal Server Error',
        });
    }

    const status = httpException.getStatus();
    const res = httpException.getResponse();
    return response.status(status).json(res);
  }
}
