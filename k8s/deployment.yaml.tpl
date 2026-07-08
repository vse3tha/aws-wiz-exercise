apiVersion: apps/v1
kind: Deployment
metadata:
  name: wizexercise-todo
  namespace: wizexercise
  labels:
    app: wizexercise-todo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wizexercise-todo
  template:
    metadata:
      labels:
        app: wizexercise-todo
    spec:
      serviceAccountName: wizexercise-admin-sa
      containers:
        - name: todo
          image: "${IMAGE_URI}"
          imagePullPolicy: Always
          ports:
            - containerPort: 3000
          env:
            - name: PORT
              value: "3000"
            - name: MONGO_URI
              valueFrom:
                secretKeyRef:
                  name: mongo-connection
                  key: MONGO_URI
          readinessProbe:
            httpGet:
              path: /healthz
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthz
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 20
