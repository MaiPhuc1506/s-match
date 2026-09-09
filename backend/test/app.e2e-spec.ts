import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

// SMM-8 — User Database & Backend Connection.
// These tests only cover what exists in this ticket's scope: the app boots,
// connects to Postgres via Prisma, and the Users endpoints respond.
// Requires a running Postgres reachable via DATABASE_URL (see backend/.env).
describe('Users / DB connection (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('/users (GET) returns an array', () => {
    return request(app.getHttpServer())
      .get('/users')
      .expect(200)
      .expect((res) => {
        if (!Array.isArray(res.body)) {
          throw new Error('Expected an array of users');
        }
      });
  });

  it('/users/:id (GET) returns 404 for a non-existent user', () => {
    return request(app.getHttpServer()).get('/users/999999').expect(404);
  });

  afterEach(async () => {
    await app.close();
  });
});
