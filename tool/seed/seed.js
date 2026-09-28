// Demo verisi: üç rol için e-postası doğrulanmış hesaplar ve örnek talepler.
//
// Emülatöre (varsayılan, güvenli):
//   firebase emulators:start --only auth,firestore --project demo-servisiz
//   npm run seed            (başka bir terminalde)
//
// Gerçek projeye (dikkat: canlı veriye yazar):
//   GOOGLE_APPLICATION_CREDENTIALS=servis-hesabi.json \
//   SEED_PASSWORD='guclu-bir-sifre' node seed.js --live
//
// Betik tekrar çalıştırılabilir: hesaplar varsa güncellenir, belgeler üzerine yazılır.
import { applicationDefault, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const live = process.argv.includes("--live");

if (!live) {
  process.env.FIRESTORE_EMULATOR_HOST ??= "127.0.0.1:8080";
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= "127.0.0.1:9099";
}

const password = process.env.SEED_PASSWORD ?? (live ? null : "demo1234");
if (!password) {
  console.error("Canlı projede SEED_PASSWORD ortam değişkeni zorunlu.");
  process.exit(1);
}

initializeApp(
  live
    ? { credential: applicationDefault() }
    : { projectId: process.env.GCLOUD_PROJECT ?? "demo-servisiz" },
);

const auth = getAuth();
const db = getFirestore();

// example.com e-posta göndermek için ayrılmış bir alan adıdır; bu hesaplara
// gerçek e-posta gitmez, bu yüzden doğrulanmış olarak açılırlar.
const accounts = {
  company: { email: "company@example.com", name: "Servisİz Teknik" },
  technician: { email: "technician@example.com", name: "Ahmet Usta", phone: "05550000001" },
  technician2: { email: "technician2@example.com", name: "Mehmet Usta", phone: "05550000002" },
  customer: { email: "customer@example.com", name: "Ayşe Yılmaz", phone: "05550000003" },
};

async function upsertUser({ email, name }) {
  try {
    const user = await auth.getUserByEmail(email);
    await auth.updateUser(user.uid, { password, displayName: name, emailVerified: true });
    return user.uid;
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    const user = await auth.createUser({ email, password, displayName: name, emailVerified: true });
    return user.uid;
  }
}

const uid = {};
for (const [key, acc] of Object.entries(accounts)) {
  uid[key] = await upsertUser(acc);
}

const now = FieldValue.serverTimestamp();
const batch = db.batch();

batch.set(db.doc(`companies/${uid.company}`), {
  name: accounts.company.name,
  email: accounts.company.email,
  createdAt: now,
});

for (const key of ["technician", "technician2"]) {
  const t = accounts[key];
  batch.set(db.doc(`technicians/${uid[key]}`), {
    name: t.name,
    email: t.email,
    phone: t.phone,
    photoUrl: "",
    rating: key === "technician" ? 4.5 : 0,
    ratingCount: key === "technician" ? 2 : 0,
    totalStars: key === "technician" ? 9 : 0,
    active: true,
    // İlk teknisyenin devam eden bir işi var.
    isAvailable: key !== "technician",
    location: key === "technician" ? { lat: 37.8746, lng: 32.4932, updatedAt: now } : null,
    createdAt: now,
  });
}

batch.set(db.doc(`customers/${uid.customer}`), {
  name: accounts.customer.name,
  email: accounts.customer.email,
  phone: accounts.customer.phone,
  createdAt: now,
});

const c = accounts.customer;
const baseRequest = {
  customerId: uid.customer,
  name: c.name,
  phone: c.phone,
  email: c.email,
  city: "Konya",
  district: "Selçuklu",
  kat: "3",
  daire: "12",
  createdAt: now,
  rated: false,
  givenStars: null,
  comment: null,
};

batch.set(db.doc("requests/demo-pending"), {
  ...baseRequest,
  issue: "Kombi su akıtıyor",
  address: "Bosna Hersek Mah. Demo Sok. No: 1",
  location: { lat: 37.8900, lng: 32.4800 },
  status: "Bekliyor",
  technicianId: null,
});

batch.set(db.doc("requests/demo-in-progress"), {
  ...baseRequest,
  issue: "Çamaşır makinesi sıkma yapmıyor",
  address: "Feritpaşa Mah. Demo Cad. No: 7",
  location: { lat: 37.8720, lng: 32.4990 },
  status: "Devam Ediyor",
  technicianId: uid.technician,
  usedParts: ["Kayış"],
  updatedAt: now,
});

batch.set(db.doc("requests/demo-completed"), {
  ...baseRequest,
  issue: "Buzdolabı soğutmuyor",
  address: "Yazır Mah. Demo Sok. No: 3",
  location: { lat: 37.9010, lng: 32.5100 },
  status: "Tamamlandı",
  technicianId: uid.technician2,
  usedParts: ["Termostat"],
  completedAt: now,
});

batch.set(db.doc("messages/demo-message"), {
  requestId: "demo-in-progress",
  senderId: uid.customer,
  receiverId: uid.technician,
  message: "Merhaba, saat kaçta gelirsiniz?",
  timestamp: now,
});

await batch.commit();

console.log(`Demo verisi yazıldı (${live ? "CANLI proje" : "emülatör"}).`);
for (const acc of Object.values(accounts)) {
  console.log(`  ${acc.email}`);
}
console.log(live ? "  Şifre: SEED_PASSWORD" : `  Şifre: ${password}`);
