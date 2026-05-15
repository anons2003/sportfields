# MH4 Evidence Pack - API Gateway Before Lambda

Project: SportFields / TopJob deployment
AWS account: `529715002875`
Region: `us-east-1`
Must-have: **MH4 - API Gateway before Lambda**

## Quyết định

Project này đặt **API Gateway REST API** trước Lambda `sportfields-dev-resize-image`.

Lý do chọn REST API:

- REST API hỗ trợ API Key và Usage Plan rõ ràng.
- Usage Plan enforce throttling cho route serverless.
- API Gateway trở thành API surface cho Lambda thay vì để backend invoke Lambda trực tiếp.

Luồng sau MH4:

```text
User
-> CloudFront
-> ALB
-> EC2 Backend
-> API Gateway REST API POST /resize-image
-> Lambda Resize Image
-> S3 user asset bucket / resized/*
```

## 1. API Gateway route

Screenshot cần có:

![API Gateway route](evidence/mh4/01-api-gateway-route.png)

Cấu hình cần thấy:

```text
API: sportfields-dev-resize-image-api
Stage: prod
Route/resource: POST /resize-image
```

## 2. Lambda proxy integration

Screenshot cần có:

![Lambda proxy integration](evidence/mh4/02-lambda-proxy-integration.png)

Cấu hình cần thấy:

```text
Integration type: Lambda Function / Lambda Proxy
Lambda function: sportfields-dev-resize-image
Method: POST
```

## 3. API key required

Screenshot cần có:

![API key required](evidence/mh4/03-api-key-required.png)

Cấu hình cần thấy:

```text
POST /resize-image
API Key Required: true
Authorization: NONE
```

Ghi chú:

MH4 dùng API Key authentication theo yêu cầu project. Request thiếu `x-api-key` phải bị API Gateway trả `403 Forbidden`.

## 4. Usage plan throttling

Screenshot cần có:

![Usage plan throttling](evidence/mh4/04-usage-plan-throttling.png)

Cấu hình cần thấy:

```text
Usage plan: sportfields-dev-resize-image-usage-plan
API key: sportfields-dev-resize-image-key
Rate limit: 10 req/s
Burst limit: 20
Stage: prod
```

## 5. Curl có API key trả 200

Screenshot cần có:

![Curl 200 with API key](evidence/mh4/05-curl-200-with-api-key.png)

Lệnh test:

```bash
curl -i -X POST "$RESIZE_IMAGE_API_URL" \
  -H "x-api-key: $RESIZE_IMAGE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"bucket":"sportfields-dev-529715002875-us-east-1-user-assets","key":"uploads/test.jpg","width":300,"height":300}'
```

Kết quả cần thấy:

```text
HTTP/2 200
outputKey: resized/...
```

## 6. Curl không có API key trả 403

Screenshot cần có:

![Curl 403 without API key](evidence/mh4/06-curl-403-without-api-key.png)

Lệnh test:

```bash
curl -i -X POST "$RESIZE_IMAGE_API_URL" \
  -H "Content-Type: application/json" \
  -d '{"bucket":"sportfields-dev-529715002875-us-east-1-user-assets","key":"uploads/test.jpg","width":300,"height":300}'
```

Kết quả cần thấy:

```text
HTTP/2 403
```

## 7. Backend gọi API Gateway

Screenshot cần có:

![Backend calls API Gateway](evidence/mh4/07-backend-calls-api-gateway.png)

Backend endpoint:

```text
POST /api/admin/images/resize
```

Ghi chú:

Endpoint admin này chạy trên EC2 backend và gọi API Gateway bằng HTTPS URL + `x-api-key`. Backend không invoke Lambda trực tiếp.

## 8. Lambda CloudWatch success log

Screenshot cần có:

![Lambda CloudWatch success log](evidence/mh4/08-lambda-cloudwatch-success.png)

Log cần thấy:

```text
resize-image-completed
bucket
key
outputKey
width
height
```

## 9. S3 resized output object

Screenshot cần có:

![S3 resized output object](evidence/mh4/09-s3-resized-output-object.png)

S3 object cần thấy:

```text
s3://sportfields-dev-529715002875-us-east-1-user-assets/resized/...
```

## Kết luận MH4

MH4 hoàn thành khi:

- API Gateway REST API có route `POST /resize-image`.
- Route dùng Lambda Proxy Integration tới `sportfields-dev-resize-image`.
- Method yêu cầu API key.
- Usage plan throttle ở `10 req/s` và `20 burst`.
- Curl có API key trả `200`.
- Curl thiếu API key trả `403`.
- Backend EC2 gọi API Gateway URL thay vì invoke Lambda trực tiếp.

Final statement:

```text
Website chính vẫn chạy qua CloudFront, ALB và EC2. Riêng chức năng resize ảnh được đưa ra sau API Gateway. EC2 Backend gọi HTTPS endpoint của API Gateway thay vì invoke Lambda trực tiếp. API Gateway enforce API Key authentication, usage plan throttling 10 req/s burst 20, và Lambda proxy integration trước Lambda Resize Image. Curl có API key trả 200, curl thiếu API key trả 403.
```
