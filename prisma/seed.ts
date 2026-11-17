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

main()
  .then(seedConfiguration)
  .finally(() => prisma.$disconnect());
