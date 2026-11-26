import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { AxiosInstance } from 'axios';
import { ConfigService } from '@nestjs/config';
import { FastApiClient } from './fastapi.client';
import { candidateData } from '../../test/helpers/matchmaking.fixture';

// Uses FastAPI's actual ASGI application in a separate Python process; no DB,
// external listener, migration, or live service is required.
const python = resolve(__dirname, '../../../matchmaking/.venv/bin/python');
const contractTest = existsSync(python) ? it : it.skip;

describe('NestJS / actual FastAPI response contract', () => {
  contractTest('accepts real five-factor FastAPI output without exposing coordinates', async () => {
    const script = `
import json
from fastapi.testclient import TestClient
from app.main import app
profile = {'skill': {'smash': 3, 'defense': 3, 'net_play': 3, 'stamina': 3, 'footwork': 3, 'serve': 3}, 'location': {'latitude': 16, 'longitude': 108}}
response = TestClient(app).post('/api/v1/match', json={'current_user': dict(profile, user_id='8'), 'candidates': [dict(profile, user_id='3'), dict(profile, user_id='7')]})
assert response.status_code == 200, response.text
print(json.dumps(response.json()))
`;
    const body = JSON.parse(execFileSync(python, ['-c', script], {
      cwd: resolve(__dirname, '../../../matchmaking'), encoding: 'utf8',
    }));
    const http = { post: jest.fn().mockResolvedValue({ status: 200, data: body }) };
    const config = { get: (key: string) => key === 'MATCHMAKING_API_URL' ? 'http://127.0.0.1:8000/api/v1/match' : undefined };
    const client = new FastApiClient(http as unknown as AxiosInstance, config as unknown as ConfigService);
    const result = await client.recommend(candidateData());
    expect(result.matchedUsers).toHaveLength(2);
    for (const row of result.matchedUsers) {
      expect(Object.keys(row.breakdown).sort()).toEqual(['distance_score', 'reliability_score', 'skill_score', 'style_score', 'time_score']);
      expect(JSON.stringify(row)).not.toMatch(/latitude|longitude|location/);
    }
  });
});
