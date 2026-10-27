import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { FindPlayerDto } from './dto/find-player.dto';

export const CANDIDATE_PROVIDER = Symbol('CANDIDATE_PROVIDER');

export interface CandidateProfile {
  userId: string;
  skill: {
    smash: number; defense: number; netPlay: number; stamina: number;
    footwork: number; serve: number; preferredMin: number; preferredMax: number;
  };
  availableTimeSlots: string[];
  location: { latitude: number; longitude: number };
  maxDistanceKm?: number | null;
  playingStyle?: string[];
  reliabilityScore?: number;
}

export interface CandidateData {
  currentUser: CandidateProfile;
  candidates: CandidateProfile[];
}

export interface CandidateProvider {
  getCandidates(userId: number, criteria: FindPlayerDto): Promise<CandidateData>;
}

@Injectable()
export class UnavailableCandidateProvider implements CandidateProvider {
  async getCandidates(_userId: number, _criteria: FindPlayerDto): Promise<CandidateData> {
    throw new ServiceUnavailableException('Dịch vụ dữ liệu ứng viên chưa sẵn sàng');
  }
}
