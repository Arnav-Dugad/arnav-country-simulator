class_name FirebaseConfig
extends RefCounted
## Firebase web config (Project settings → General → Your apps → Web app).
## The web API key is NOT a secret: it only identifies the project. Security
## comes from firestore.rules (each user can only touch users/{their uid}/…).
## Leave empty to run fully offline (cloud features hide themselves).

const API_KEY := ""
const PROJECT_ID := ""


static func is_configured() -> bool:
	return API_KEY != "" and PROJECT_ID != ""
