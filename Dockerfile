# -------- Build stage --------
FROM golang:1.22-alpine AS build
WORKDIR /src
# ถ้า repo ของคุณคือ nanomdm เอง ให้ COPY ทั้งหมด
COPY . .
# ปิด CGO เพื่อได้ไบนารี static และระบุแพลตฟอร์มตอน build
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ENV CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH

# ดึง dependency และ build สองไบนารีหลัก
RUN go mod download
RUN go build -ldflags="-s -w" -o /out/nanomdm ./cmd/nanomdm
RUN go build -ldflags="-s -w" -o /out/nano2nano ./cmd/nano2nano

# -------- Runtime stage --------
# ใช้ distroless base ที่มี CA certs สำหรับ TLS (APNs/DB)
FROM gcr.io/distroless/base-debian12
WORKDIR /app

# คัดลอกไบนารีจาก build stage
COPY --from=build /out/nanomdm /app/nanomdm
COPY --from=build /out/nano2nano /app/nano2nano

# ✅ คัดลอกไฟล์ CA และ APNs เข้า image
# ต้องแน่ใจว่าโฟลเดอร์ ./ca และ ./certs อยู่ใน repo ของคุณ
COPY ./ca/ca.pem /data/ca/ca.pem
COPY ./certs/mdm_push.p8 /data/certs/mdm_push.p8

# ไม่ใช้ VOLUME (Railway ห้าม) — ไป mount เป็น Railway Volume แทน
EXPOSE 9000

# รันด้วย user ปลอดภัย (มีใน distroless)
USER nonroot:nonroot
ENTRYPOINT ["/app/nanomdm"]
