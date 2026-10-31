import { isISO8601 } from 'class-validator';
import { CandidateData, CandidateProfile } from './candidate-provider';

export function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

const inRange = (value: unknown, min: number, max: number): value is number =>
  typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;

export function isCandidateProfile(value: unknown): value is CandidateProfile {
  if (!isRecord(value) || typeof value.userId !== 'string' || !value.userId.trim() ||
      !isRecord(value.skill) || !isRecord(value.location)) return false;
  const skill = value.skill;
  if (!['smash', 'defense', 'netPlay', 'stamina', 'footwork', 'serve']
    .every((key) => inRange(skill[key], 0, 5))) return false;
  if (!inRange(skill.preferredMin, 1, 5) || !Number.isInteger(skill.preferredMin) ||
      !inRange(skill.preferredMax, 1, 5) || !Number.isInteger(skill.preferredMax) ||
      skill.preferredMin > skill.preferredMax) return false;
  return Array.isArray(value.availableTimeSlots) && value.availableTimeSlots.every((slot) =>
    typeof slot === 'string' && isISO8601(slot, { strict: true }) && /T.*(?:Z|[+-]\d{2}:\d{2})$/.test(slot)) &&
    inRange(value.location.latitude, -90, 90) && inRange(value.location.longitude, -180, 180) &&
    (value.maxDistanceKm === undefined || value.maxDistanceKm === null || inRange(value.maxDistanceKm, 0, Number.MAX_VALUE)) &&
    (value.playingStyle === undefined || (Array.isArray(value.playingStyle) && value.playingStyle.every((s) => typeof s === 'string'))) &&
    (value.reliabilityScore === undefined || inRange(value.reliabilityScore, 0, 5));
}

export function isCandidateData(value: unknown, userId?: number): value is CandidateData {
  if (!isRecord(value) || !isCandidateProfile(value.currentUser) ||
      (userId !== undefined && value.currentUser.userId !== String(userId)) || !Array.isArray(value.candidates) ||
      !value.candidates.every(isCandidateProfile)) return false;
  return new Set(value.candidates.map((candidate) => candidate.userId)).size === value.candidates.length;
}
