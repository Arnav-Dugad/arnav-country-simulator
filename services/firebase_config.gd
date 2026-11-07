class_name FirebaseConfig
extends RefCounted
## Firebase web config (Project settings → General → Your apps → Web app).
## The web API key is NOT a secret: it only identifies the project. Security
## comes from firestore.rules (each user can only touch users/{their uid}/…).
## Leave empty to run fully offline (cloud features hide themselves).

const API_KEY := "AIzaSyBPbHtm1cUMZoQiip5p5A2b5CmocVwrK_E"
const PROJECT_ID := "arnav-country-simulator"


static func is_configured() -> bool:
	return API_KEY != "" and PROJECT_ID != ""
