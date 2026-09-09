import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Cấu hình tài liệu Swagger cho S-Match
  const config = new DocumentBuilder()
    .setTitle('S-Match API Documentation')
    .setDescription('Tài liệu API hệ thống đặt sân và ghép người chơi S-Match')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api', app, document);

  await app.listen(3000);
}
bootstrap();