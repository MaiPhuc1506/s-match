import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class MatchmakingService {
  constructor(private readonly httpService: HttpService) {}

  async getRecommendedMatches(matchPayload: any) {
    const pythonApiUrl = 'http://127.0.0.1:8000/api/v1/match';

    try {
      const response = await firstValueFrom(
        this.httpService.post(pythonApiUrl, matchPayload),
      );
      return response.data;
    } catch (error) {
      throw new HttpException(
        'Không thể kết nối đến Matchmaking Service (Python)',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }
}