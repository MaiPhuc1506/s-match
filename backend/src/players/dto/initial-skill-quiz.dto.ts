import { ArrayMaxSize, ArrayMinSize, IsArray, IsInt, Max, Min } from 'class-validator';

export class InitialSkillQuizDto {
  @IsArray()
  @ArrayMinSize(6)
  @ArrayMaxSize(6)
  @IsInt({ each: true })
  @Min(0, { each: true })
  @Max(4, { each: true })
  answers: number[];
}
