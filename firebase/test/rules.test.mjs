// Firestore 规则测试:在本机模拟器里跑(npm test 会自动起停模拟器)。
// 核心要求:爸爸妈妈权限相同、谁邀请谁都一样;只有验证过的被邀请邮箱能加入;外人什么都看不到。

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  arrayRemove, arrayUnion, collection, deleteDoc, deleteField, doc, getDoc, getDocs, query, serverTimestamp, setDoc, updateDoc, where,
} from 'firebase/firestore';

let env;
const FID = 'fam1';
const mom = { uid: 'mom', email: 'mom@example.com' };
const dad = { uid: 'dad', email: 'dad@example.com' };
const eve = { uid: 'eve', email: 'eve@example.com' };

const ctx = (u, verified = true) => env.authenticatedContext(u.uid, { email: u.email, email_verified: verified }).firestore();
const item = (by, kind = 'task', id = 't1') => ({ kind, id, json: JSON.stringify({ id }), t: 1, by, at: serverTimestamp() });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-schoolsift',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // 妈妈建好的家庭,邀请了爸爸(dad@example.com)
  await env.withSecurityRulesDisabled(async (c) => {
    const db = c.firestore();
    await setDoc(doc(db, 'families', FID), {
      memberUids: [mom.uid], memberEmails: { [mom.uid]: mom.email }, inviteEmails: [dad.email], createdBy: mom.uid,
    });
    await setDoc(doc(db, 'families', FID, 'items', 'task_t0'), item(mom.uid, 'task', 't0'));
  });
});

const join = (db, u) => updateDoc(doc(db, 'families', FID), {
  memberUids: arrayUnion(u.uid), inviteEmails: arrayRemove(u.email), [`memberEmails.${u.uid}`]: u.email,
});

describe('建家庭', () => {
  test('验证过邮箱的人只能把自己放进新家庭', async () => {
    const db = ctx(eve);
    await assertSucceeds(setDoc(doc(db, 'families', 'new1'), { memberUids: [eve.uid], memberEmails: { [eve.uid]: eve.email }, inviteEmails: [], createdBy: eve.uid }));
    await assertFails(setDoc(doc(db, 'families', 'new2'), { memberUids: [eve.uid, mom.uid], memberEmails: { [eve.uid]: eve.email }, inviteEmails: [] }));
  });
  test('没验证邮箱不能建', async () => {
    await assertFails(setDoc(doc(ctx(eve, false), 'families', 'new3'), { memberUids: [eve.uid], memberEmails: { [eve.uid]: eve.email }, inviteEmails: [] }));
  });
});

describe('邀请与加入', () => {
  test('外人和未登录的人看不到家庭', async () => {
    await assertFails(getDoc(doc(ctx(eve), 'families', FID)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'families', FID)));
    await assertFails(getDocs(collection(ctx(eve), 'families', FID, 'items')));
  });
  test('被邀请的邮箱验证过才能看到邀请(含按邮箱查询)', async () => {
    await assertFails(getDoc(doc(ctx(dad, false), 'families', FID)));
    await assertSucceeds(getDoc(doc(ctx(dad), 'families', FID)));
    await assertSucceeds(getDocs(query(collection(ctx(dad), 'families'), where('inviteEmails', 'array-contains', dad.email))));
    await assertFails(getDocs(query(collection(ctx(eve), 'families'), where('inviteEmails', 'array-contains', dad.email))));
  });
  test('被邀请但还没加入时读不到记录', async () => {
    await assertFails(getDocs(collection(ctx(dad), 'families', FID, 'items')));
  });
  test('爸爸接受邀请:只把自己加进去', async () => {
    await assertFails(join(ctx(dad, false), dad));
    await assertFails(updateDoc(doc(ctx(dad), 'families', FID), {
      memberUids: arrayUnion(dad.uid, eve.uid), inviteEmails: arrayRemove(dad.email), [`memberEmails.${dad.uid}`]: dad.email,
    }));
    await assertSucceeds(join(ctx(dad), dad));
  });
  test('没被邀请的人不能把自己加进去', async () => {
    await assertFails(join(ctx(eve), eve));
  });
});

describe('加入后:权限完全相同', () => {
  beforeEach(async () => { await join(ctx(dad), dad); });

  test('双方都能读写删全部记录(谁建的都一样)', async () => {
    for (const u of [mom, dad]) {
      const db = ctx(u);
      await assertSucceeds(getDocs(collection(db, 'families', FID, 'items')));
      await assertSucceeds(setDoc(doc(db, 'families', FID, 'items', `task_${u.uid}`), item(u.uid, 'task', u.uid)));
    }
    await assertSucceeds(setDoc(doc(ctx(dad), 'families', FID, 'items', 'task_t0'), item(dad.uid, 'task', 't0'))); // 改妈妈建的
    await assertSucceeds(deleteDoc(doc(ctx(dad), 'families', FID, 'items', 'task_mom')));
  });
  test('记录格式不对或冒名(by 不是自己)被拒', async () => {
    const db = ctx(dad);
    await assertFails(setDoc(doc(db, 'families', FID, 'items', 'task_x'), item(mom.uid, 'task', 'x')));
    await assertFails(setDoc(doc(db, 'families', FID, 'items', 'wrongid'), item(dad.uid, 'task', 'x')));
    await assertFails(setDoc(doc(db, 'families', FID, 'items', 'virus_x'), item(dad.uid, 'virus', 'x')));
  });
  test('照片:成员能传,超过 1 MB 被拒,外人读不到', async () => {
    const db = ctx(dad);
    await assertSucceeds(setDoc(doc(db, 'families', FID, 'images', 'img1'), { b64: 'aGVsbG8=', by: dad.uid, at: serverTimestamp() }));
    await assertFails(setDoc(doc(db, 'families', FID, 'images', 'img2'), { b64: 'a'.repeat(1000001), by: dad.uid, at: serverTimestamp() }));
    await assertFails(getDoc(doc(ctx(eve), 'families', FID, 'images', 'img1')));
  });
  test('双方都能邀请、撤回邀请', async () => {
    await assertSucceeds(updateDoc(doc(ctx(dad), 'families', FID), { inviteEmails: arrayUnion('grandma@example.com') }));
    await assertSucceeds(updateDoc(doc(ctx(mom), 'families', FID), { inviteEmails: arrayRemove('grandma@example.com') }));
  });
  test('只能把自己移出家庭,不能踢别人', async () => {
    await assertFails(updateDoc(doc(ctx(dad), 'families', FID), { memberUids: arrayRemove(mom.uid), [`memberEmails.${mom.uid}`]: deleteField() }));
    await assertSucceeds(updateDoc(doc(ctx(dad), 'families', FID), { memberUids: arrayRemove(dad.uid), [`memberEmails.${dad.uid}`]: deleteField() }));
    await assertFails(getDocs(collection(ctx(dad), 'families', FID, 'items')));
  });
  test('成员不能删家庭、不能改别的字段', async () => {
    await assertFails(deleteDoc(doc(ctx(mom), 'families', FID)));
    await assertFails(updateDoc(doc(ctx(mom), 'families', FID), { createdBy: dad.uid }));
  });
});

describe('删除账号', () => {
  test('最后一个成员能删光家庭的记录和照片、清空邀请、移出自己、删自己的账号记录', async () => {
    const db = ctx(mom);
    await assertSucceeds(setDoc(doc(db, 'families', FID, 'images', 'i1'), { b64: 'aGVsbG8=', by: mom.uid, at: serverTimestamp() }));
    await assertSucceeds(setDoc(doc(db, 'users', mom.uid), { familyId: FID, email: mom.email }));
    await assertSucceeds(deleteDoc(doc(db, 'families', FID, 'items', 'task_t0')));
    await assertSucceeds(deleteDoc(doc(db, 'families', FID, 'images', 'i1')));
    await assertSucceeds(updateDoc(doc(db, 'families', FID), { inviteEmails: [] }));
    await assertSucceeds(updateDoc(doc(db, 'families', FID), { memberUids: arrayRemove(mom.uid), [`memberEmails.${mom.uid}`]: deleteField() }));
    await assertSucceeds(deleteDoc(doc(db, 'users', mom.uid)));
  });
});

describe('users/{uid}', () => {
  test('只能读写自己的', async () => {
    await assertSucceeds(setDoc(doc(ctx(dad), 'users', dad.uid), { familyId: FID, email: dad.email }));
    await assertSucceeds(getDoc(doc(ctx(dad), 'users', dad.uid)));
    await assertSucceeds(getDoc(doc(ctx(eve), 'users', eve.uid))); // 还没有记录时也能读(返回不存在)
    await assertFails(getDoc(doc(ctx(eve), 'users', dad.uid)));
    await assertFails(setDoc(doc(ctx(eve), 'users', dad.uid), { familyId: 'x' }));
  });
});
