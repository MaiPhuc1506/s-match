import { validate } from 'class-validator';
import { CreateFacilityDto } from './dto/create-facility.dto';
import { UpdateFacilityDto } from './dto/update-facility.dto';
import { FacilitiesService } from './facilities.service';
import { PrismaService } from '../prisma/prisma.service';

describe('facility coordinate validation', () => {
  it('rejects coordinates outside world bounds', async () => {
    const dto = Object.assign(new CreateFacilityDto(), { name: 'A', address: 'B', latitude: 91, longitude: 181 });
    const errors = await validate(dto);
    expect(errors.map(e => e.property)).toEqual(expect.arrayContaining(['latitude', 'longitude']));
  });
  it('accepts valid coordinates on update', async () => {
    expect(await validate(Object.assign(new UpdateFacilityDto(), { latitude: 16, longitude: 108 }))).toHaveLength(0);
  });
  it('rejects a partial coordinate pair on creation', async () => {
    const service = new FacilitiesService({} as PrismaService);
    await expect(service.createFacility(2, { name: 'A', address: 'B', latitude: 16 })).rejects.toMatchObject({ status: 400 });
  });
});
