from pydantic_settings import BaseSettings


class Settings(BaseSettings):
  # Matchmaking Weight Configurations (Tổng = 100)
  WEIGHT_SKILL: float = 30.0
  WEIGHT_DISTANCE: float = 25.0
  WEIGHT_TIME: float = 20.0
  WEIGHT_STYLE: float = 10.0
  WEIGHT_RELIABILITY: float = 15.0

  # Matchmaking Thresholds
  MAX_DISTANCE_KM: float = 20.0

  class Config:
    env_file = ".env"


settings = Settings()