# Dockerizing Mern-Application


## Table of Contents
- [Building the Docker Images](#building-the-docker-image)
- [Pushing Images to DockerHub](#pushing-images-to-dockerhub)
- [K8s Deployment Object](#k8s-deployment-object)
- [Github Actions Workflow](#github-actions-workflow)
## Building the Docker Image
1. Creating dockerfile for the frontend.
```bash
FROM node:21-alpine3.17
WORKDIR /app
COPY . .
RUN npm install && \
    cd frontend && \
    npm install
WORKDIR /app/frontend
CMD ["npm","run","dev"]
```
- Using the Node.js 21 image with Alpine Linux 3.17 as the base image.
- Setting the working directory inside the container to `/app`.
- Copying the local files into the `/app` directory in the container.
- Dependency Installation:
  - Running `npm install` in the root directory (`/app`) to install backend dependencies as frontend dependencies need backend dependencies.
  - Using `cd frontend` to get into frontend directory.
  - Running `npm install` again to install frontend dependencies.
- Changing the working directory to `/app/frontend` as CMD runs in WORKDIR.
- Specifying the default entry point to run when the container starts. It executes the `npm run dev` command, to start frontend.

2. Creating dockerfile for the backend.
```bash
FROM node:21-alpine3.17
WORKDIR /app
COPY . .
RUN npm install && \
    cd frontend && \
    npm install
CMD ["npm","start"]
```
- Using the Node.js 21 image with Alpine Linux 3.17 as the base image.
- Setting the working directory inside the container to `/app`.
- Copying the local files into the `/app` directory in the container.
- Dependency Installation: 
  - Installing backend dependencies by running `npm install`.
  - Using `cd frontend` to navigate to the frontend directory before installing frontend dependencies by `npm install`.
- Specifying the default entry point to run when the container starts as `npm start`, to start the backend.

3. Creating docker compose file to run the app (frontend+backend) & database on the same network.
```bash
version: "3.1"

services:
  frontend:
    build:
      dockerfile: frontend.dockerfile
    ports:
      - 5173:5173
    depends_on:
      - backend
  backend:
    build:
      dockerfile: backend.dockerfile
    ports:
      - 5000:5000
    depends_on:
      - database
  database:
    image: mongo
    restart: always
    environment:
      - MONGO_INITDB_ROOT_USERNAME=wec
      - MONGO_INITDB_ROOT_PASSWORD=wec
    ports:
      - "27017:27017"
```
Using Docker Compose configuration in version 3.1, which defines a multi-container application with frontend, backend, and a MongoDB database:

- Services: Defines the different services or containers that make up the application.

  - Frontend:
    - Uses previously created Dockerfile for frontend defined in `frontend.dockerfile`.
    - Maps port 5173 on the host to port 5173 in the container.
    - Depends on the "backend" service.

  - Backend:
    - Uses previously created Dockerfile for backend defined in `backend.dockerfile`.
    - Maps port 5000 on the host to port 5000 in the container.
    - Depends on the "database" service.

  - Database (MongoDB):
    - Uses the official MongoDB image from Docker Hub.
    - Sets the `MONGO_INITDB_ROOT_USERNAME` and `MONGO_INITDB_ROOT_PASSWORD` environment variables for initial MongoDB user setup.
    - Maps port 27017 on the host to port 27017 in the container.
    - The "restart: always" ensures that the MongoDB container restarts automatically if it stops.

This Docker Compose file orchestrates the setup of three interconnected containers: a frontend, a backend, and a MongoDB database, allowing them to work together as a multi-service application.

4. Creating .env file
```bash
MONGO_URI="mongodb://wec:wec@database:27017/admin"
PORT = 5000
JWT_SECRET="str"
```
5. Running ```docker compose up --build``` to build the images and run the containers.

    the containers are running but can't access the webpage

    ![cont](./captures/cont.png?raw=true "cont")

    ![webpage](./captures/webpage_error.png?raw=true "webpage")
   
    when i checked the logs, the frontend wasn't exposed to the network.
   
    ![frontend](./captures/frontend_error.png?raw=true "frontend")
   
    i found the solution on this [page](https://bobbyhadz.com/blog/expose-local-vite-app-to-network) and updated the frontend               package.json file

    changed ` "dev": "vite" ` to ` "dev": "vite --host" ` under scripts
 
    ![json](./captures/fixed_json.png?raw=true "json")

    now the frontend was exposed to the network

    ![front](./captures/frontend_fix.png?raw=true "front")

     now the webpage was working
     ![web](./captures/webpage.png?raw=true "web")
   
## Pushing Images to DockerHub
1. Taging the backend image ``` docker tag wec-containerization-backend:latest arzan03/wec-containerization-backend:latest ```
2. Pushing the image to docker hub ``` docker push arzan03/wec-containerization-backend:latest ```
3. Taging the front image ``` docker tag wec-containerization-frontend:latest arzan03/wec-containerization-frontend:latest ```
4. Pushing the image to docker hub ``` docker push arzan03/wec-containerization-frontend:latest ```

## K8s Deployment Object
Created k8s deployemnt .yaml file
```bash
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  selector:
    app: database
  ports:
    - protocol: TCP
      port: 27017
      targetPort: 27017

---

apiVersion: v1
kind: Service
metadata:
  name: frontend-network
spec:
  selector:
    app: frontend
  ports:
    - name: "frontend-port"
      protocol: TCP
      port: 5173
      targetPort: 5173
  type: NodePort

---

apiVersion: v1
kind: Service
metadata:
  name: backend-network
spec:
  selector:
    app: backend
  ports:
    - name: "backend-port"
      protocol: TCP
      port: 5000
      targetPort: 5000
  type: NodePort

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  labels:
    app: database
spec:
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: database
        image: mongo
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: wec
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: wec

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: arzan03/wec-containerization-backend
        ports:
        - containerPort: 5000
          hostPort: 5000
          protocol: TCP

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: arzan03/wec-containerization-frontend
        ports:
        - containerPort: 5173
          hostPort: 5173
          protocol: TCP

```
This YAML configuration defines Kubernetes resources, including Services and Deployments for a database, backend, and frontend components.

1. **Database Service**:
   - A Service named "database" exposing port 27017 for MongoDB.
   - It selects Pods with the label `app: database`.

2. **Frontend Network Service**:
   - A Service named "frontend-network" exposing port 5173 for the frontend component.
   - It selects Pods with the label `app: frontend`.
   - This service is of type NodePort, allowing external access.

3. **Backend Network Service**:
   - A Service named "backend-network" exposing port 5000 for the backend component.
   - It selects Pods with the label `app: backend`.
   - This service is also of type NodePort.

4. **Database Deployment**:
   - A Deployment named "database" for MongoDB.
   - It uses a MongoDB image.
   - Defines environment variables for the MongoDB root user credentials.

5. **Backend Deployment**:
   - A Deployment named "backend" for the backend component.
   - It uses the Docker image from my repo in DockerHub.
   - Exposes port 5000, both in the container and on the host.

6. **Frontend Deployment**:
   - A Deployment named "frontend" for the frontend component.
   - It also uses my DockerHub image.
   - Exposes port 5173, both in the container and on the host.

**Container Port:** The container port is the port number on which a process or application inside a container is listening.

**HostPort:** The host port is a port number on the underlying host machine (the node) that is associated with a specific container port

**NodePort:** Node port is a type of service in Kubernetes that exposes a specific port on all nodes in the cluster. NodePort services are typically used to expose a service to the external world when you want to access it from outside the cluster. Any traffic that arrives at a node's IP address on the NodePort will be forwarded to the associated service.

These YAML configurations describe how the different components of the application are deployed and how they can be accessed within a Kubernetes cluster. The Services expose specific ports for each component, and the Deployments define how the application containers should be deployed and managed. The type of Services "frontend-network" and "backend-network" as NodePort suggests that these services can be accessed externally via a node's IP address and a high port number(>30,000).

Everything is running without errors.

![kube](./captures/kube.png?raw=true "kube")

backend is exposed on port 31242

![front](./captures/kube_front.png?raw=true "front")

frontend is exposed on port 32219

![back](./captures/kube_back.png?raw=true "back")

## GitHub Actions Workflow
Created GitHub Actions workflow file for build and push
```bash
name: Docker Image CI

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:

  build:

    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        name: Check out code
    
      - uses: mr-smithers-excellent/docker-build-push@v6
        name: Build & push frontend Docker image
        with:
          image: arzan03/wec-containerization-frontend
          tags: latest
          registry: docker.io
          dockerfile: frontend.dockerfile
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      - uses: mr-smithers-excellent/docker-build-push@v6
        name: Build & push backend Docker image
        with:
          image: arzan03/wec-containerization-backend
          tags: latest
          registry: docker.io
          dockerfile: backend.dockerfile
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}    

```
This workflow automates the building and pushing of Docker images for frontend and backend components:

1. **Triggers**: The workflow is triggered on two events:
   - `push`: It runs when code is pushed to the "main" branch.
   - `pull_request`: It runs when a pull request is opened or updated for the "main" branch.

2. **Jobs**: The workflow defines a single job named "build and push" that runs on Ubuntu-latest which has docker pre-instaled.

3. **Steps**:

   a. `actions/checkout@v3`: This step checks out the code from the repository.

   b. `mr-smithers-excellent/docker-build-push@v6`: This step uses a custom action to build and push Docker images. It is used twice, once for the frontend and once for the backend.

This workflow is designed to automatically build and push Docker images for the "main" branch of the repository when changes are pushed or when pull requests are made. It uses custom Docker image building and pushing actions, and it relies on Docker credentials stored as secrets to access the Docker registry.
![actions](./captures/actions.png?raw=true "actions")

