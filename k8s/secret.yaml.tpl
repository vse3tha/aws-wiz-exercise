apiVersion: v1
kind: Secret
metadata:
  name: mongo-connection
  namespace: wizexercise
type: Opaque
stringData:
  MONGO_URI: "${MONGO_URI}"
