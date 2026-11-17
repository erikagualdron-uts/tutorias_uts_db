import 'dotenv/config';
import argon2 from 'argon2';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '@prisma/client';

const email = process.env.SEED_ADMIN_EMAIL?.trim().toLowerCase();
const password = process.env.SEED_ADMIN_PASSWORD;
if (!email || !password) {
  throw new Error('SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD are required');
}

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
});

async function main() {
  const passwordHash = await argon2.hash(password!);
  await prisma.user.upsert({
    where: { email },
    update: {},
    create: {
      email: email!,
      passwordHash,
      role: 'SUPERADMIN',
      emailVerifiedAt: new Date(),
      mustChangePassword: true,
    },
  });
}

// Example data for development (spec 006): skipped when the table already has rows.
async function seedConfiguration() {
  if ((await prisma.academicPeriod.count({ where: { deletedAt: null } })) === 0) {
    await prisma.academicPeriod.create({
      data: {
        name: 'Ejemplo 2026-2',
        startsOn: new Date('2026-07-20T00:00:00Z'),
        endsOn: new Date('2027-01-31T00:00:00Z'),
        status: 'ACTIVE',
      },
    });
  }
  if ((await prisma.location.count({ where: { deletedAt: null } })) === 0) {
    await prisma.location.create({
      data: {
        name: 'Sede Central',
        rooms: {
          create: [
            { name: 'A-101', capacity: 30 },
            { name: 'A-102', capacity: 25 },
            { name: 'Lab-1', capacity: 20 },
          ],
        },
      },
    });
  }
}

// Example data for development (spec 010): holidays of the example period and one module with its
// weekly sessions. Skipped when the tables already have rows.
async function seedModules() {
  if ((await prisma.holiday.count({ where: { deletedAt: null } })) === 0) {
    const holidays: [string, string][] = [
      ['2026-08-17', 'Asunción de la Virgen'],
      ['2026-10-12', 'Día de la Raza'],
      ['2026-11-02', 'Día de Todos los Santos'],
      ['2026-11-16', 'Independencia de Cartagena'],
      ['2026-12-08', 'Inmaculada Concepción'],
      ['2026-12-25', 'Navidad'],
      ['2027-01-01', 'Año Nuevo'],
      ['2027-01-11', 'Día de los Reyes Magos'],
    ];
    await prisma.holiday.createMany({
      data: holidays.map(([date, name]) => ({ date: new Date(`${date}T00:00:00Z`), name })),
    });
  }
  if ((await prisma.module.count({ where: { deletedAt: null } })) > 0) return;
  const period = await prisma.academicPeriod.findFirst({ where: { status: 'ACTIVE', deletedAt: null } });
  const room = await prisma.room.findFirst({ where: { name: 'A-101', deletedAt: null } });
  if (!period || !room) return;
  const teacher = await prisma.user.upsert({
    where: { email: 'docente.ejemplo@correo.uts.edu.co' },
    update: {},
    create: {
      email: 'docente.ejemplo@correo.uts.edu.co',
      passwordHash: await argon2.hash(password!),
      role: 'TEACHER',
      emailVerifiedAt: new Date(),
      mustChangePassword: true,
      teacherProfile: { create: { firstName: 'Docente', lastName: 'Ejemplo' } },
    },
  });
  // Tuesdays 14:00-16:00 in Bogota (UTC-5), from the first Tuesday of the period, without holidays.
  const holidayDays = new Set((await prisma.holiday.findMany()).map((h) => h.date.toISOString().slice(0, 10)));
  const module = await prisma.module.create({
    data: {
      periodId: period.id,
      teacherId: teacher.id,
      roomId: room.id,
      name: 'Cálculo I (ejemplo)',
      description: 'Módulo de ejemplo para desarrollo.',
      schedules: {
        create: { periodId: period.id, teacherId: teacher.id, roomId: room.id, dayOfWeek: 2, startMinute: 840, endMinute: 960 },
      },
    },
    include: { schedules: true },
  });
  const day = new Date(period.startsOn);
  day.setUTCDate(day.getUTCDate() + ((2 - day.getUTCDay() + 7) % 7));
  for (; day <= period.endsOn; day.setUTCDate(day.getUTCDate() + 7)) {
    if (holidayDays.has(day.toISOString().slice(0, 10))) continue;
    const startsAt = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), 19));
    await prisma.moduleSession.create({
      data: {
        moduleId: module.id,
        scheduleId: module.schedules[0]!.id,
        teacherId: teacher.id,
        roomId: room.id,
        originalStartsAt: startsAt,
        startsAt,
        endsAt: new Date(startsAt.getTime() + 2 * 3_600_000),
      },
    });
  }
}

main()
  .then(seedConfiguration)
  .then(seedModules)
  .finally(() => prisma.$disconnect());
