// web/firebase_config.js
const firebaseConfig = {
    apiKey: "AIzaSyDcY5GjBFaJ-swvEJHBGsTiTE1qbumHIco",
    authDomain: "lifematters-c466d.firebaseapp.com",
    projectId: "lifematters-c466d",
    storageBucket: "lifematters-c466d.firebasestorage.app",
    messagingSenderId: "162639628951",
    appId: "1:162639628951:web:aa90df6b0da482942637d2",
    measurementId: "G-FEV7L0C0PB"
};

if (typeof firebase !== 'undefined' && firebase.apps.length === 0) {
    firebase.initializeApp(firebaseConfig);
    console.log('✅ arinacave Firebase initialized');

    firebase.auth().setPersistence(firebase.auth.Auth.Persistence.LOCAL)
        .then(() => console.log('✅ Auth persistence set to LOCAL'))
        .catch((e) => console.error('❌ Auth persistence error:', e));
}