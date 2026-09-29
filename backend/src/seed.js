require('dotenv').config();
require('./db');
const bcrypt = require('bcryptjs');
const { Admin } = require('./models');

async function seed() {
  const name = process.env.SEED_ADMIN_NAME || 'Super Admin';
  const email = process.env.SEED_ADMIN_EMAIL || 'admin@temple.com';
  const password = process.env.SEED_ADMIN_PASSWORD || 'Admin@123';

  const existing = await Admin.findOne({ email });
  if (existing) {
    console.log(`Admin ${email} already exists. Skipping.`);
    process.exit(0);
  }
  const password_hash = await bcrypt.hash(password, 10);
  await Admin.create({ name, email, password_hash });
  console.log('Admin created:', email, '/', password);
  process.exit(0);
}

seed().catch(err => { console.error(err); process.exit(1); });
