const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// యాప్ ఇనిషియలైజ్
admin.initializeApp();

// 🌟 డాక్యుమెంట్ క్రియేట్ అయినప్పుడు రన్ అయ్యే ఫంక్షన్
exports.sendPushNotification = onDocumentCreated("notifications/{docId}", async (event) => {
    // కొత్తగా యాడ్ అయిన డేటా
    const data = event.data.data();
    
    if (!data) return null; // డేటా లేకపోతే ఆపేస్తాం

    const receiverId = data.receiverId;
    const senderId = data.senderId;
    const type = data.type; // 'like', 'follow', 'comment'

    try {
        // 1. రిసీవర్ టోకెన్ లాగడం
        const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
        if (!userDoc.exists) {
            console.log("యూజర్ దొరకలేదు");
            return null;
        }
        
        const fcmToken = userDoc.data().fcmToken;
        if (!fcmToken) {
            console.log("ఈ యూజర్‌కి FCM టోకెన్ లేదు");
            return null;
        }

        // 2. సెండర్ వివరాలు లాగడం
        const senderDoc = await admin.firestore().collection("users").doc(senderId).get();
        const senderName = senderDoc.exists ? senderDoc.data().username : "Someone";

        // 3. నోటిఫికేషన్ టైటిల్ & బాడీ రెడీ చేయడం
        let title = "New Notification";
        let body = `${senderName} interacted with your post.`;

        if (type === "like") {
            title = "New Like! ❤️";
            body = `${senderName} liked your post.`;
        } else if (type === "follow") {
            title = "New Follower! 👤";
            body = `${senderName} started following you.`;
        } else if (type === "comment") {
            title = "New Comment! 💬";
            body = `${senderName} commented on your post.`;
        }

        // 4. మెసేజ్ పేలోడ్ (Payload)
        const payload = {
            notification: {
                title: title,
                body: body,
            },
            token: fcmToken
        };

        // 5. ఫైర్‌బేస్ మెసేజింగ్ ద్వారా నోటిఫికేషన్ పంపడం
        const response = await admin.messaging().send(payload);
        console.log("సక్సెస్! మెసేజ్ వెళ్ళిపోయింది:", response);
        return null;

    } catch (error) {
        console.error("ఎర్రర్ వచ్చింది బాస్:", error);
        return null;
    }
});