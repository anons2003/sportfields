# MH2 Evidence Pack - Network Firewall Hardening

Project: SportFields / TopJob deployment  
AWS account: `529715002875`  
Region: `us-east-1`  
VPC: `sportfields-dev-vpc` / `vpc-03fee4bca2c513e22`  
Path đã chọn: **Path A - Deploy AWS Network Firewall**

## Quyết định

Project này dùng **AWS Network Firewall** vì backend EC2 chạy trong private application subnet và cần outbound internet thông qua NAT Gateway. Do EC2 có egress qua NAT, path hardened SG + NACL không hợp lệ cho MH2.

Luồng traffic:

```text
EC2 trong private-app subnet
-> Network Firewall endpoint trong firewall subnet
-> Firewall subnet route table
-> NAT Gateway trong public NAT subnet
-> Internet Gateway
-> Internet
```

Firewall được deploy trong dedicated firewall subnets. EC2 application không đặt trong các firewall subnet này.

## 1. Bằng chứng topology

Screenshot cần có:

- Trang chi tiết Network Firewall hiển thị firewall endpoints và sync state.

![Network Firewall endpoints and sync state](evidence/mh2/01-firewall-endpoints-sync.png)

Cấu hình quan sát được:

```text
Firewall name: sportfields-dev-network-firewall
Firewall status: Ready
Firewall policy: sportfields-dev-firewall-policy
Stateful rule group: sportfields-dev-domain-allowlist
Configuration sync state: In sync
```

Firewall endpoints:

| Availability Zone | Firewall subnet | Endpoint ID | Status |
| --- | --- | --- | --- |
| `us-east-1a` | `subnet-0b9cee962f9f8ae93` | `vpce-0871361efa17ac154` | Ready |
| `us-east-1b` | `subnet-0159c331a990839b9` | `vpce-094e69bfafcabb59c` | Ready |

## 2. Bằng chứng firewall subnet

Screenshot cần có:

- Bảng Network Firewall endpoint.
- Trang subnet hoặc firewall details thể hiện endpoint subnets.

![Dedicated firewall subnets](evidence/mh2/01-firewall-endpoints-sync.png)

Dedicated firewall subnets:

| Name | Subnet ID | AZ | CIDR |
| --- | --- | --- | --- |
| `sportfields-dev-firewall-1` | `subnet-0b9cee962f9f8ae93` | `us-east-1a` | `10.30.30.0/24` |
| `sportfields-dev-firewall-2` | `subnet-0159c331a990839b9` | `us-east-1b` | `10.30.31.0/24` |

Ghi chú: các subnet này chỉ dùng cho Network Firewall endpoints, không dùng để đặt EC2, ALB, RDS hoặc application workload.

## 3. Bằng chứng firewall policy

Screenshot cần có:

- Trang `sportfields-dev-firewall-policy` hiển thị stateful rule order và default actions.

![Firewall policy strict order and default actions](evidence/mh2/03-firewall-policy.png)

Cấu hình policy:

```text
Firewall policy: sportfields-dev-firewall-policy
Rule order: Strict order
Stateless default action: Forward to stateful rule groups
Stateless fragmented packet action: Forward to stateful rule groups
Stateful default actions:
- Alert established
- Drop established
```

Stateful rule group đã gắn vào policy:

| Priority | Rule group | Capacity |
| --- | --- | --- |
| `1` | `sportfields-dev-domain-allowlist` | `100` |

## 4. Bằng chứng stateful domain allowlist

Screenshot cần có:

- Trang rule group `sportfields-dev-domain-allowlist` hiển thị type, status và danh sách domain.

![Stateful domain allowlist rule group](evidence/mh2/04-domain-allowlist.png)

Cấu hình rule group:

```text
Name: sportfields-dev-domain-allowlist
Type: Stateful
Status: Active
Stateful rule order: Strict order
Action: Allow
Protocols: HTTP, HTTPS
Target types: HTTP_HOST, TLS_SNI
```

Các domain được allow:

```text
api.stripe.com
checkout.stripe.com
accounts.google.com
oauth2.googleapis.com
generativelanguage.googleapis.com
.googleapis.com
.amazonaws.com
```

Rationale:

- Stripe được allow cho các API liên quan đến payment.
- Google domains được allow cho authentication và Google API integrations.
- `.amazonaws.com` được allow để EC2/SSM và AWS service communication vẫn hoạt động từ private subnets.
- Các HTTPS destination khác không nằm trong allowlist sẽ bị firewall policy chặn.

## 5. Bằng chứng route table

Screenshots cần có:

- `sportfields-dev-private-app-rt-1`
- `sportfields-dev-private-app-rt-2`
- `sportfields-dev-firewall-rt`
- `sportfields-dev-public-nat-rt-1`

![Private app route table 1 to firewall endpoint](evidence/mh2/05a-private-app-rt-1.png)

Private app route table ở `us-east-1a`:

```text
Route table: rtb-0a428435b111f5558 / sportfields-dev-private-app-rt-1
Associated subnet: subnet-06925c3f4054bd952 / sportfields-dev-private-app-1

10.30.0.0/16 -> local
0.0.0.0/0   -> vpce-0871361efa17ac154
```

![Private app route table 2 to firewall endpoint](evidence/mh2/05b-private-app-rt-2.png)

Private app route table ở `us-east-1b`:

```text
Route table: rtb-0b40d26a95c5d4a0f / sportfields-dev-private-app-rt-2
Associated subnet: subnet-0b11d62d69b8d3cf1 / sportfields-dev-private-app-2

10.30.0.0/16 -> local
0.0.0.0/0   -> vpce-094e69bfafcabb59c
```

![Firewall route table to NAT Gateway](evidence/mh2/05c-firewall-rt.png)

Firewall subnet route table:

```text
Route table: rtb-07d46b4dd2dfcc423 / sportfields-dev-firewall-rt
Associated subnets:
- subnet-0b9cee962f9f8ae93 / sportfields-dev-firewall-1
- subnet-0159c331a990839b9 / sportfields-dev-firewall-2

10.30.0.0/16 -> local
0.0.0.0/0   -> nat-02995eee8c2d0185c
```

![Public NAT route table with return routes to firewall endpoints](evidence/mh2/05d-public-nat-rt.png)

Public NAT route table:

```text
Route table: rtb-06b2bb2828621b945 / sportfields-dev-public-nat-rt-1
Associated subnet: subnet-09233dff4a6991a21 / sportfields-dev-public-nat-1

0.0.0.0/0    -> igw-0721b44bfd8d2e511
10.30.0.0/16 -> local
10.30.10.0/24 -> vpce-0871361efa17ac154
10.30.11.0/24 -> vpce-094e69bfafcabb59c
```

Ghi chú routing quan trọng:

NAT Gateway được đặt trong một public NAT subnet riêng để return traffic từ NAT có thể được route ngược qua firewall endpoint. Cách này giữ traffic path đối xứng:

```text
Private app subnet -> Firewall endpoint -> NAT Gateway -> Internet
Internet response -> NAT subnet route table -> Firewall endpoint -> Private app subnet
```

## 6. Bằng chứng request được allow

Screenshot cần có:

- Terminal hoặc SSM shell hiển thị request tới `api.stripe.com`.

![Allowed request to Stripe](evidence/mh2/06-allowed-blocked-example.png)

Lệnh test:

```bash
curl -I https://api.stripe.com
```

Kết quả quan sát được:

```text
HTTP/2 404
server: nginx
content-type: application/json
```

Giải thích:

`HTTP/2 404` là kết quả hợp lệ cho allowed test này. Request đã reach được Stripe; `404` là response từ Stripe vì test gọi root endpoint mà không có API path cụ thể.

## 7. Bằng chứng request bị block

Screenshot cần có:

- Terminal hoặc SSM shell hiển thị request tới `example.com` bị chặn.

![Blocked request to example.com](evidence/mh2/06-allowed-blocked-example.png)

Lệnh test:

```bash
curl -I --max-time 10 https://example.com
```

Kết quả quan sát được:

```text
curl: (28) Connection timed out after 10002 milliseconds
```

Giải thích:

`example.com` không nằm trong domain allowlist, nên outbound HTTPS request bị AWS Network Firewall chặn. Điều này chứng minh private app subnet không còn đi thẳng tới NAT Gateway, mà bị ép đi qua firewall endpoint trước.

## 8. Bằng chứng Alert Logs

Screenshot cần có:

- CloudWatch Logs event trong log group `/aws/network-firewall/sportfields-dev/alert`.

![Network Firewall Alert Logs drop event](evidence/mh2/08-alertlogs.png)

Log group:

```text
CloudWatch Logs group: /aws/network-firewall/sportfields-dev/alert
Log stream: /aws/network-firewall/alert/sportfields-dev-network-firewall_2026-05-14-09
```

Event quan sát được:

```text
firewall_name: sportfields-dev-network-firewall
availability_zone: us-east-1a
src_ip: 10.30.10.69
event_type: alert
alert.action: blocked
verdict.action: drop
proto: TCP
dest_port: 443
pkt_src: geneve encapsulation
direction: to_server
```

Giải thích:

Alert Logs hiển thị Network Firewall đã inspect outbound HTTPS traffic từ EC2 private app subnet `10.30.10.69` và drop packet TCP port `443`. Trường `pkt_src: geneve encapsulation` cho thấy traffic đi qua firewall endpoint, đúng với route path đã thiết kế.
