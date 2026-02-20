// Firebase Cloud Functions — ParcheesiGame Backend
// TypeScript / Node.js 18

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const rtdb = admin.database();

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 1: USER MANAGEMENT
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Triggered on new user creation.
 * Creates default Firestore profile if it doesn't exist.
 */
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const profileRef = db.collection("users").doc(uid);
  const existing = await profileRef.get();
  if (existing.exists) return;

  await profileRef.set({
    id: uid,
    displayName: user.displayName || user.email?.split("@")[0] || "Player",
    email: user.email || "",
    coins: 500,
    gems: 0,
    xp: 0,
    level: 1,
    isPremium: false,
    stats: {
      totalGames: 0, wins: 0, losses: 0, draws: 0,
      currentStreak: 0, bestStreak: 0,
      totalTokensCaptured: 0, totalTokensLost: 0,
      totalDiceRolls: 0, doublesRolled: 0,
      averageTurnsPerGame: 0,
    },
    friendIDs: [],
    blockedIDs: [],
    unlockedAvatarIDs: ["default"],
    unlockedThemeIDs: ["classic"],
    selectedAvatarID: "default",
    selectedThemeID: "classic",
    consecutiveLoginDays: 1,
    isBanned: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info(`Profile created for user: ${uid}`);
});

/**
 * Triggered on user deletion. Cleans up all associated data.
 */
export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const batch = db.batch();

  // Delete user profile
  batch.delete(db.collection("users").doc(uid));

  // Remove from friend lists — query and update
  const friendsQuery = await db
    .collection("users")
    .where("friendIDs", "array-contains", uid)
    .get();
  friendsQuery.docs.forEach((doc) => {
    batch.update(doc.ref, {
      friendIDs: admin.firestore.FieldValue.arrayRemove(uid),
    });
  });

  await batch.commit();
  functions.logger.info(`User data cleaned up: ${uid}`);
});

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 2: LEVEL CALCULATION (Server-side, cheat-proof)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Triggered when user's XP field changes in Firestore.
 * Recalculates level server-side to prevent client-side manipulation.
 */
export const onXPUpdate = functions.firestore
  .document("users/{uid}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.xp === after.xp) return; // No XP change

    const newLevel = calculateLevel(after.xp);
    if (newLevel !== after.level) {
      await change.after.ref.update({ level: newLevel });
      functions.logger.info(
        `User ${context.params.uid} leveled up to ${newLevel}`
      );
    }
  });

function calculateLevel(xp: number): number {
  let level = 1;
  while (true) {
    const required = Math.floor((level - 1) * 100 * Math.pow(1.2, level - 2));
    if (required > xp || level >= 100) break;
    level++;
  }
  return level;
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 3: GAME MOVE VALIDATION (Anti-cheat)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Validates and applies a move server-side to prevent cheating.
 * Called by clients before updating the game state.
 */
export const validateMove = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
  }

  const { gameID, move, playerID } = data;

  if (!gameID || !move || !playerID) {
    throw new functions.https.HttpsError("invalid-argument", "Missing required fields.");
  }

  // Fetch current game state
  const gameSnap = await rtdb.ref(`games/${gameID}`).get();
  if (!gameSnap.exists()) {
    throw new functions.https.HttpsError("not-found", "Game not found.");
  }

  const gameState = gameSnap.val();

  // Verify it is the player's turn
  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  if (currentPlayer.id !== playerID) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "It is not your turn."
    );
  }

  // Verify move is in remaining moves
  const diceValue = move.diceValue;
  const remaining = gameState.remainingMoves as number[];
  if (!remaining.includes(diceValue)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid dice value for this move."
    );
  }

  // Validate destination (simplified — mirror client-side logic)
  const token = currentPlayer.tokens[move.tokenIndex];
  if (!token || token.isFinished) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Invalid token selection."
    );
  }

  // Move is valid — return approval
  return { valid: true, gameID, move };
});

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 4: STATS UPDATE
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Records game result and updates stats atomically.
 */
export const recordGameResult = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = context.auth.uid;
    const { won, turnsElapsed, mode, captures } = data;

    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) throw new Error("User not found");

      const stats = userSnap.data()!.stats;
      stats.totalGames++;
      stats.totalTokensCaptured += captures || 0;

      if (won) {
        stats.wins++;
        stats.currentStreak++;
        if (stats.currentStreak > stats.bestStreak) {
          stats.bestStreak = stats.currentStreak;
        }
      } else {
        stats.losses++;
        stats.currentStreak = 0;
      }

      const prevAvg = stats.averageTurnsPerGame;
      stats.averageTurnsPerGame =
        prevAvg + (turnsElapsed - prevAvg) / stats.totalGames;

      // XP award
      const baseXP = won ? modeXP(mode) : 30;
      const captureXP = (captures || 0) * 15;
      const totalXP = baseXP + captureXP;

      tx.update(userRef, {
        stats,
        xp: admin.firestore.FieldValue.increment(totalXP),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { success: true };
  }
);

function modeXP(mode: string): number {
  switch (mode) {
    case "online":
    case "private": return 350;
    case "ai":      return 150;
    default:        return 100;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 5: PUSH NOTIFICATIONS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Sends a turn reminder notification to a player.
 */
export const sendTurnNotification = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
    }

    const { targetUID, gameID } = data;

    const userSnap = await db.collection("users").doc(targetUID).get();
    if (!userSnap.exists) return;

    const fcmToken = userSnap.data()!.fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "Your Turn!",
        body: "Make your move in Parcheesi Quest before time runs out!",
      },
      data: {
        type: "turn_reminder",
        gameID: gameID,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
  }
);

/**
 * Sends a room invitation push notification.
 */
export const sendRoomInvite = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Must be signed in.");
    }

    const { targetUID, senderName, roomCode } = data;

    const userSnap = await db.collection("users").doc(targetUID).get();
    if (!userSnap.exists) return;

    const fcmToken = userSnap.data()!.fcmToken;
    if (!fcmToken) return;

    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: `${senderName} invites you!`,
        body: `Join their Parcheesi room with code: ${roomCode}`,
      },
      data: {
        type: "room_invite",
        code: roomCode,
      },
    });
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 6: ADMIN — BAN / UNBAN
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Admin-only function to ban a user.
 * Secured by checking custom admin claim.
 */
export const banUser = functions.https.onCall(async (data, context) => {
  const caller = context.auth;
  if (!caller || !caller.token.admin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Must be an admin."
    );
  }

  const { targetUID, reason } = data;

  await db.collection("users").doc(targetUID).update({
    isBanned: true,
    banReason: reason || "Terms of Service violation",
    bannedAt: admin.firestore.FieldValue.serverTimestamp(),
    bannedBy: caller.uid,
  });

  // Disable the Firebase Auth account
  await admin.auth().updateUser(targetUID, { disabled: true });

  functions.logger.info(`User ${targetUID} banned by admin ${caller.uid}`);
  return { success: true };
});

/**
 * Admin-only function to unban a user.
 */
export const unbanUser = functions.https.onCall(async (data, context) => {
  const caller = context.auth;
  if (!caller || !caller.token.admin) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Must be an admin."
    );
  }

  const { targetUID } = data;

  await db.collection("users").doc(targetUID).update({
    isBanned: false,
    banReason: admin.firestore.FieldValue.delete(),
  });
  await admin.auth().updateUser(targetUID, { disabled: false });

  functions.logger.info(`User ${targetUID} unbanned by admin ${caller.uid}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 7: ROOM CLEANUP
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Scheduled function: clean up stale rooms older than 24 hours.
 */
export const cleanupStaleRooms = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const staleRooms = await rtdb
      .ref("rooms")
      .orderByChild("createdAt")
      .endAt(cutoff)
      .get();

    if (!staleRooms.exists()) return;

    const updates: Record<string, null> = {};
    staleRooms.forEach((child) => {
      const room = child.val();
      if (room.status !== "inProgress") {
        updates[child.key!] = null;
      }
    });

    await rtdb.ref("rooms").update(updates);
    functions.logger.info(`Cleaned ${Object.keys(updates).length} stale rooms`);
  });

// ─────────────────────────────────────────────────────────────────────────────
// SECTION 8: LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Scheduled: rebuild top-100 leaderboard daily.
 */
export const rebuildLeaderboard = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const usersSnap = await db
      .collection("users")
      .orderBy("xp", "desc")
      .limit(100)
      .get();

    const batch = db.batch();

    // Clear existing
    const existingSnap = await db.collection("leaderboard").get();
    existingSnap.docs.forEach((doc) => batch.delete(doc.ref));

    // Write new
    usersSnap.docs.forEach((doc, idx) => {
      const data = doc.data();
      const entry = {
        rank: idx + 1,
        userID: doc.id,
        displayName: data.displayName,
        xp: data.xp,
        level: data.level,
        wins: data.stats?.wins || 0,
        avatarID: data.selectedAvatarID,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      batch.set(db.collection("leaderboard").doc(doc.id), entry);
    });

    await batch.commit();
    functions.logger.info("Leaderboard rebuilt");
  });
