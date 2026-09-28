// Firestore güvenlik kuralları testleri (emülatörde çalışır): `npm test`
import { readFileSync } from "node:fs";
import { after, before, beforeEach, describe, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  setLogLevel,
  writeBatch,
} from "firebase/firestore";

let env;
setLogLevel("silent");

const CUSTOMER = "cust1";
const OTHER_CUSTOMER = "cust2";
const UNVERIFIED = "cust3";
const TECH = "tech1";
const TECH2 = "tech2";
const COMPANY = "comp1";
const STRANGER = "nobody";

const db = (uid, verified = true) =>
  env.authenticatedContext(uid, { email_verified: verified }).firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-servisiz",
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    for (const id of [CUSTOMER, OTHER_CUSTOMER, UNVERIFIED]) {
      await setDoc(doc(f, "customers", id), { name: id, email: `${id}@x.com`, phone: "1" });
    }
    for (const id of [TECH, TECH2]) {
      await setDoc(doc(f, "technicians", id), {
        name: id, active: true, isAvailable: true,
        totalStars: 0, ratingCount: 0, rating: 0,
      });
    }
    await setDoc(doc(f, "companies", COMPANY), { name: "Firma" });
    await setDoc(doc(f, "requests", "pending"), {
      customerId: CUSTOMER, status: "Bekliyor", technicianId: null, rated: false,
    });
    await setDoc(doc(f, "requests", "active"), {
      customerId: CUSTOMER, status: "Devam Ediyor", technicianId: TECH, rated: false,
    });
    await setDoc(doc(f, "requests", "done"), {
      customerId: CUSTOMER, status: "Tamamlandı", technicianId: TECH, rated: false,
    });
    await setDoc(doc(f, "messages", "m1"), {
      requestId: "active", senderId: CUSTOMER, receiverId: TECH, message: "selam",
    });
  });
});

const newRequest = (uid) => ({
  customerId: uid, status: "Bekliyor", technicianId: null, rated: false,
  givenStars: null, comment: null, issue: "Kombi",
});

// Uygulamadaki puanlama transaction'ının aynısı.
const rate = (f, reqId, techId, stars) =>
  runTransaction(f, async (t) => {
    const reqRef = doc(f, "requests", reqId);
    const techRef = doc(f, "technicians", techId);
    const tech = (await t.get(techRef)).data();
    const total = (tech.totalStars ?? 0) + stars;
    const count = (tech.ratingCount ?? 0) + 1;
    t.update(reqRef, { rated: true, givenStars: stars, comment: "iyi" });
    t.update(techRef, {
      totalStars: total, ratingCount: count, rating: total / count, lastRatedRequest: reqId,
    });
  });

// Uygulamadaki görev alma işleminin aynısı.
const take = (f, reqId, techId) => {
  const b = writeBatch(f);
  b.update(doc(f, "requests", reqId), { technicianId: techId, status: "Devam Ediyor" });
  b.update(doc(f, "technicians", techId), { isAvailable: false });
  return b.commit();
};

describe("rol yükseltme", () => {
  test("kimse kendini şirket yapamaz", async () => {
    await assertFails(setDoc(doc(db(STRANGER), "companies", STRANGER), { name: "x" }));
  });
  test("kimse kendini teknisyen yapamaz", async () => {
    await assertFails(setDoc(doc(db(STRANGER), "technicians", STRANGER), { name: "x" }));
  });
  test("şirket teknisyen ekleyebilir", async () => {
    await assertSucceeds(setDoc(doc(db(COMPANY), "technicians", "yeni"), { name: "y" }));
  });
  test("yeni kullanıcı müşteri kaydı açabilir (doğrulanmadan)", async () => {
    await assertSucceeds(
      setDoc(doc(db(STRANGER, false), "customers", STRANGER), { name: "a", email: "e", phone: "p" }),
    );
  });
  test("teknisyen kendine müşteri kaydı açamaz", async () => {
    await assertFails(setDoc(doc(db(TECH), "customers", TECH), { name: "a" }));
  });
  test("müşteri kaydını silemez", async () => {
    await assertFails(deleteDoc(doc(db(CUSTOMER), "customers", CUSTOMER)));
  });
});

describe("müşteri verisi", () => {
  test("müşteri başka müşteriyi okuyamaz", async () => {
    await assertFails(getDoc(doc(db(CUSTOMER), "customers", OTHER_CUSTOMER)));
  });
  test("şirket müşterileri listeler", async () => {
    await assertSucceeds(getDocs(collection(db(COMPANY), "customers")));
  });
  test("teknisyen müşteri listesini çekemez ama tek belge okuyabilir", async () => {
    await assertFails(getDocs(collection(db(TECH), "customers")));
    await assertSucceeds(getDoc(doc(db(TECH), "customers", CUSTOMER)));
  });
});

describe("e-posta doğrulaması", () => {
  test("doğrulanmamış müşteri talep açamaz", async () => {
    await assertFails(addDoc(collection(db(UNVERIFIED, false), "requests"), newRequest(UNVERIFIED)));
  });
  test("doğrulanmış müşteri talep açar", async () => {
    await assertSucceeds(addDoc(collection(db(CUSTOMER), "requests"), newRequest(CUSTOMER)));
  });
  test("müşteri atanmış ya da tamamlanmış talep açamaz", async () => {
    await assertFails(
      addDoc(collection(db(CUSTOMER), "requests"), { ...newRequest(CUSTOMER), status: "Tamamlandı" }),
    );
    await assertFails(
      addDoc(collection(db(CUSTOMER), "requests"), { ...newRequest(CUSTOMER), technicianId: TECH }),
    );
  });
});

describe("görev alma", () => {
  test("teknisyen bekleyen işi müsaitliğiyle birlikte alır", async () => {
    await assertSucceeds(take(db(TECH), "pending", TECH));
  });
  test("müsaitliğini düşürmeden iş alamaz", async () => {
    await assertFails(
      updateDoc(doc(db(TECH), "requests", "pending"), { technicianId: TECH, status: "Devam Ediyor" }),
    );
  });
  test("zaten görevdeyken ikinci işi alamaz", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), "technicians", TECH), { isAvailable: false }));
    await assertFails(take(db(TECH), "pending", TECH));
  });
  test("başkasının aldığı işi alamaz", async () => {
    await assertSucceeds(take(db(TECH), "pending", TECH));
    await assertFails(take(db(TECH2), "pending", TECH2));
  });
  test("alırken başka alanı değiştiremez", async () => {
    const f = db(TECH);
    const b = writeBatch(f);
    b.update(doc(f, "requests", "pending"), { technicianId: TECH, status: "Devam Ediyor", customerId: TECH });
    b.update(doc(f, "technicians", TECH), { isAvailable: false });
    await assertFails(b.commit());
  });
  test("teknisyen kendi işini tamamlar, başkasına devredemez", async () => {
    await assertSucceeds(updateDoc(doc(db(TECH), "requests", "active"), { status: "Tamamlandı" }));
    await assertFails(updateDoc(doc(db(TECH2), "requests", "active"), { status: "Tamamlandı" }));
  });
  test("teknisyen kendi işini başkasına atayamaz", async () => {
    await assertFails(updateDoc(doc(db(TECH), "requests", "active"), { technicianId: TECH2 }));
  });
  test("teknisyen kendi puanını değiştiremez", async () => {
    await assertFails(updateDoc(doc(db(TECH), "technicians", TECH), { rating: 5 }));
    await assertSucceeds(updateDoc(doc(db(TECH), "technicians", TECH), { isAvailable: true }));
  });
  test("teknisyen başka müşterinin bekleyen talebini okuyabilir (iş seçmek için)", async () => {
    await assertSucceeds(getDocs(query(collection(db(TECH2), "requests"), where("status", "==", "Bekliyor"))));
  });
  test("teknisyen tüm talepleri listeleyemez", async () => {
    await assertFails(getDocs(collection(db(TECH2), "requests")));
  });
});

describe("puanlama", () => {
  test("müşteri tamamlanan işini bir kez puanlar", async () => {
    await assertSucceeds(rate(db(CUSTOMER), "done", TECH, 4));
    await assertFails(rate(db(CUSTOMER), "done", TECH, 5));
  });
  test("puanlama olmadan teknisyen puanı değiştirilemez", async () => {
    await assertFails(
      updateDoc(doc(db(CUSTOMER), "technicians", TECH), { totalStars: 500, ratingCount: 1, rating: 500 }),
    );
  });
  test("toplam verilen yıldızdan fazla artırılamaz", async () => {
    const f = db(CUSTOMER);
    const b = writeBatch(f);
    b.update(doc(f, "requests", "done"), { rated: true, givenStars: 1, comment: "" });
    b.update(doc(f, "technicians", TECH), {
      totalStars: 100, ratingCount: 1, rating: 100, lastRatedRequest: "done",
    });
    await assertFails(b.commit());
  });
  test("başka müşteri puanlayamaz", async () => {
    await assertFails(rate(db(OTHER_CUSTOMER), "done", TECH, 5));
  });
  test("bitmemiş iş puanlanamaz", async () => {
    await assertFails(rate(db(CUSTOMER), "active", TECH, 5));
  });
  test("yıldız 1-5 arasında olmalı", async () => {
    await assertFails(rate(db(CUSTOMER), "done", TECH, 50));
  });
});

describe("mesajlar", () => {
  test("talebin tarafları mesajları sorgular", async () => {
    const q = (f) => query(collection(f, "messages"), where("requestId", "==", "active"));
    await assertSucceeds(getDocs(q(db(CUSTOMER))));
    await assertSucceeds(getDocs(q(db(TECH))));
  });
  test("yabancı mesajları okuyamaz ya da listeleyemez", async () => {
    await assertFails(getDocs(query(collection(db(TECH2), "messages"), where("requestId", "==", "active"))));
    await assertFails(getDocs(collection(db(CUSTOMER), "messages")));
    await assertFails(getDoc(doc(db(OTHER_CUSTOMER), "messages", "m1")));
  });
  test("müşteri yalnız atanan teknisyene yazar", async () => {
    const msg = (to) => ({ requestId: "active", senderId: CUSTOMER, receiverId: to, message: "merhaba" });
    await assertSucceeds(addDoc(collection(db(CUSTOMER), "messages"), msg(TECH)));
    await assertFails(addDoc(collection(db(CUSTOMER), "messages"), msg(TECH2)));
  });
  test("yabancı bir talebe mesaj yazamaz", async () => {
    await assertFails(addDoc(collection(db(TECH2), "messages"), {
      requestId: "active", senderId: TECH2, receiverId: CUSTOMER, message: "x",
    }));
  });
});

describe("şirket", () => {
  test("şirket teknisyen atar ve talepleri yönetir", async () => {
    await assertSucceeds(take(db(COMPANY), "pending", TECH));
    await assertSucceeds(deleteDoc(doc(db(COMPANY), "requests", "done")));
  });
  test("müşteri yalnız kendi bekleyen talebini siler", async () => {
    await assertFails(deleteDoc(doc(db(CUSTOMER), "requests", "active")));
    await assertSucceeds(deleteDoc(doc(db(CUSTOMER), "requests", "pending")));
  });
});
