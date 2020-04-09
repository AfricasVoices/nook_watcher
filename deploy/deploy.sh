# Exit immediately if a command exits with a non-zero status
set -e
if [ $# -ne 1 ]; then
    echo "Usage: $0 path/to/firebase/deployment/constants.json"
    exit 1
fi

########## validate argument(s)

FIREBASE_CONSTANTS="$1"
if [ ! -f "$FIREBASE_CONSTANTS" ]; then
  echo "could not find FIREBASE_CONSTANTS: $FIREBASE_CONSTANTS"
  exit 1
fi

WORK_DIR="$(pwd)"

cd "$(dirname "$FIREBASE_CONSTANTS")"
FIREBASE_CONSTANTS_DIR="$(pwd)"
FIREBASE_CONSTANTS_FILENAME="$(basename "$FIREBASE_CONSTANTS")"
FIREBASE_CONSTANTS_FILE="$FIREBASE_CONSTANTS_DIR/$FIREBASE_CONSTANTS_FILENAME"


########## cd to the nook project directory and get the absolute path

cd "$WORK_DIR"
cd "$(dirname "$0")"/..
PROJDIR="$(pwd)"


########## rebuild the webapp

# Remove previous build if it exists
rm -rf public

# Build
cd webapp
echo "building webapp ..."
webdev build
echo "build complete"
mv build ../public
cd ..

# Copy the constants in the build folder
cp $FIREBASE_CONSTANTS_FILE public/assets/firebase_constants.json


########## deploy webapp

# Get the project id
echo "getting project id..."
PROJECT_ID=$(cat $FIREBASE_CONSTANTS | python -c 'import json,sys; constants=json.load(sys.stdin); print(constants["projectId"])')
echo "project id: $PROJECT_ID"

# Deploy using the local firebase instance
echo "deploying to firebase..."
firebase deploy --only hosting --project $PROJECT_ID --public public
echo "firebase deploy result: $?"

echo "deployment complete"
