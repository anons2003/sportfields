# Stretch Goal Evidence - API Gateway Custom Domain

Project: SportFields / TopJob deployment  
AWS account: `529715002875`  
Region: `us-east-1`  
Hosted zone: `topjob.id.vn` / `Z001215534TG6WOOKP0BR`  
Custom domain: `api-gw.topjob.id.vn`

## Mục tiêu

Stretch goal yêu cầu gắn custom domain với ACM certificate vào stage API Gateway.

Kết quả đã triển khai:

```text
https://api-gw.topjob.id.vn
-> API Gateway HTTP API
-> $default stage
-> backend integration tới https://api.topjob.id.vn
-> ALB
-> EC2 backend
```

Không thay đổi domain production hiện tại:

```text
api.topjob.id.vn -> ALB backend hiện tại
app.topjob.id.vn -> CloudFront frontend
assets.topjob.id.vn -> CloudFront/S3 assets
```

Lý do dùng subdomain riêng `api-gw.topjob.id.vn`: chứng minh stretch goal API Gateway custom domain mà không làm ảnh hưởng traffic production đang đi qua `api.topjob.id.vn`.

## 1. ACM Certificate

![ACM certificate issued for API Gateway custom domain](evidence/api-gateway-custom-domain/01-acm-certificate-issued.png)

Cấu hình:

```text
Domain name: api-gw.topjob.id.vn
Certificate ARN: arn:aws:acm:us-east-1:529715002875:certificate/34af4d40-64b7-4822-9736-8a12a6537675
Status: ISSUED
Issued at: 2026-05-15T11:07:54+07:00
Validation method: DNS
Region: us-east-1
```

Giải thích:

API Gateway Regional custom domain cần ACM certificate hợp lệ trong cùng region với API. Certificate này đã được DNS-validated qua Route 53 hosted zone `topjob.id.vn`.

## 2. API Gateway HTTP API

![API Gateway HTTP API details](evidence/api-gateway-custom-domain/02-http-api-details.png)

Cấu hình:

```text
API name: sportfields-dev-http-api
API ID: vmbblwng4g
Protocol type: HTTP
API endpoint: https://vmbblwng4g.execute-api.us-east-1.amazonaws.com
Stage: $default
Auto deploy: enabled
```

Integration target:

```text
https://api.topjob.id.vn
```

Giải thích:

HTTP API được dùng làm API Gateway surface cho stretch goal. API này proxy request tới backend hiện tại qua domain ALB `api.topjob.id.vn`, nên không cần thay đổi backend code hay ALB hiện có.

## 3. API Gateway Custom Domain

![API Gateway custom domain available](evidence/api-gateway-custom-domain/03-custom-domain-available.png)

Cấu hình:

```text
Custom domain: api-gw.topjob.id.vn
Status: AVAILABLE
Endpoint type: REGIONAL
Security policy: TLS 1.2
Regional domain name: d-ovtgmh7olg.execute-api.us-east-1.amazonaws.com
API Gateway hosted zone ID: Z1UJRXOUMOOFQ8
Certificate: api-gw.topjob.id.vn
```

Giải thích:

Custom domain dùng endpoint type `REGIONAL` để khớp với API Gateway và ACM certificate trong `us-east-1`. TLS được terminate tại API Gateway bằng ACM certificate của `api-gw.topjob.id.vn`.

## 4. API Mapping

![API Gateway API mapping to default stage](evidence/api-gateway-custom-domain/04-api-mapping.png)

Cấu hình:

```text
Domain name: api-gw.topjob.id.vn
API mapping ID: xwqney
API ID: vmbblwng4g
API name: sportfields-dev-http-api
Stage: $default
API mapping key: empty/root mapping
```

Giải thích:

API mapping key để trống, nên root domain được map trực tiếp vào `$default` stage:

```text
https://api-gw.topjob.id.vn/health
-> $default stage
-> backend /health
```

Nếu có mapping key như `/api`, URL sẽ dài hơn và evidence test sẽ kém trực quan hơn. Root mapping giúp test custom domain rõ ràng.

## 5. Route 53 DNS Record

![Route 53 alias record for API Gateway custom domain](evidence/api-gateway-custom-domain/05-route53-alias-record.png)

Cấu hình:

```text
Hosted zone: topjob.id.vn
Record name: api-gw.topjob.id.vn
Record type: A
Alias: Yes
Alias target: d-ovtgmh7olg.execute-api.us-east-1.amazonaws.com
Alias hosted zone ID: Z1UJRXOUMOOFQ8
```

Giải thích:

Route 53 A Alias trỏ domain `api-gw.topjob.id.vn` tới API Gateway Regional domain. Dùng Alias A thay vì CNAME vì đây là cách AWS-native, phù hợp với Route 53 và API Gateway.

## 6. Test Custom Domain

![curl test through API Gateway custom domain](evidence/api-gateway-custom-domain/06-curl-health-test.png)

Lệnh test:

```bash
curl -i https://api-gw.topjob.id.vn/health
```

Kết quả quan sát được:

```text
HTTP/2 200
content-type: application/json; charset=utf-8
apigw-requestid: dY1xTiN_IAMESgQ=

{"status":"healthy", ... "env":"production"}
```

Giải thích:

`HTTP/2 200` chứng minh custom domain gọi được backend health endpoint. Header `apigw-requestid` chứng minh request đi qua API Gateway, không phải gọi thẳng ALB.

## 7. So sánh và phản biện

### Vì sao không dùng `api.topjob.id.vn`

`api.topjob.id.vn` đang là production backend domain trỏ thẳng ALB. Nếu đổi domain này sang API Gateway ngay, frontend/backend traffic hiện tại có thể bị ảnh hưởng. Vì vậy stretch goal dùng subdomain riêng:

```text
api-gw.topjob.id.vn
```

Cách này chứng minh custom domain API Gateway nhưng vẫn giữ production path ổn định.

### Vì sao dùng Regional custom domain

Regional custom domain đơn giản, rõ ràng và khớp với API Gateway trong `us-east-1`. ACM certificate cũng nằm trong `us-east-1`.

So với edge-optimized custom domain, Regional tránh việc API Gateway tạo CloudFront managed distribution ngầm, giảm thời gian propagate và dễ giải thích hơn trong evidence.

### Vì sao dùng HTTP API

HTTP API đủ cho custom domain demonstration và có latency/cost thấp hơn REST API. Với stretch goal này, yêu cầu chính là custom domain + ACM + stage mapping, không yêu cầu usage plan/API key.

Nếu cần các tính năng REST API như usage plan, API key hoặc method-level throttling theo REST API, có thể migrate mapping sang REST API sau.
