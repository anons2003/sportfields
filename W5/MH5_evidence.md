# MH5 Evidence Pack - Reserved Concurrency

Project: SportFields / TopJob deployment
AWS account: `529715002875`
Region: `us-east-1`
Must-have: **MH5 - Serverless Scaling Pattern**

## Quyết định

Project này dùng **Reserved Concurrency** trên Lambda `sportfields-dev-resize-image`.

Lý do:

- Lambda Resize Image là function thật trong ứng dụng, đang xử lý avatar profile.
- Backend EC2 gọi Lambda qua API Gateway khi user/owner/admin upload avatar.
- Image processing có thể tăng tải đột biến nếu nhiều user upload cùng lúc.
- Reserved Concurrency giới hạn số concurrent invocations để workload resize không dùng hết account concurrency.

Luồng ứng dụng:

```text
User
-> CloudFront
-> ALB
-> EC2 Backend
-> API Gateway POST /resize-image
-> Lambda Resize Image
-> S3 user asset bucket / resized/profiles/*
```

## 1. Lambda reserved concurrency

Screenshot cần có:

![Lambda reserved concurrency](evidence/mh5/01-lambda-reserved-concurrency.png)

Cấu hình cần thấy:

```text
Function: sportfields-dev-resize-image
Reserved concurrency: 10
```

## 2. Parallel invocation test

Screenshot cần có:

![Parallel invocation test](evidence/mh5/02-parallel-invocation-test.png)

Test cần thấy:

```text
20 direct Lambda invokes chạy song song
Một số invoke thành công
Một số invoke bị TooManyRequestsException / throttled
```

Ghi chú:

Stress test dùng direct Lambda invoke để chứng minh Lambda-level throttle. API Gateway usage plan vẫn được test ở MH4.

## 3. CloudWatch Throttles metric

Screenshot cần có:

![CloudWatch Throttles metric](evidence/mh5/03-cloudwatch-throttles-metric.png)

Metric cần thấy:

```text
Namespace: AWS/Lambda
FunctionName: sportfields-dev-resize-image
Metric: Throttles
Statistic: Sum
Datapoint: > 0
```

## 4. Successful resize after throttle

Screenshot cần có:

![Successful resize after throttle](evidence/mh5/04-successful-resize-after-throttle.png)

Kết quả cần thấy:

```text
Upload avatar hoặc invoke resize sau stress test vẫn trả success
profileImageId/outputKey nằm dưới resized/profiles/ hoặc resized/
```

## 5. S3 resized avatar object

Screenshot cần có:

![S3 resized avatar object](evidence/mh5/05-s3-resized-avatar-object.png)

Object cần thấy:

```text
s3://sportfields-dev-529715002875-us-east-1-user-assets/resized/profiles/...
CloudFront/asset URL trả 200
```

## Kết luận MH5

MH5 hoàn thành khi:

- Lambda thật `sportfields-dev-resize-image` có Reserved Concurrency = `10`.
- Stress test vượt concurrency limit tạo throttle.
- CloudWatch Lambda metric `Throttles` có datapoint lớn hơn `0`.
- App flow upload avatar vẫn resize thành công sau khi test.

Final statement:

```text
MH5 dùng Reserved Concurrency trên Lambda Resize Image, function thật đang xử lý avatar profile của SportFields. Nhóm set Reserved Concurrency = 10 để giới hạn số concurrent invocations, tránh image-processing workload dùng hết Lambda account concurrency và ảnh hưởng Lambda khác. Khi số invoke vượt quá limit, Lambda bị throttle và CloudWatch ghi nhận metric Throttles, chứng minh scaling control đang hoạt động.
```
