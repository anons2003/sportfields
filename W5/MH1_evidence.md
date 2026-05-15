# MH1 — Multi-VPC Connectivity

## 1. Lựa chọn kiến trúc & Rationale
**Lựa chọn:** Nhóm chọn Path C - Justified Single-VPC

**Rationale:**
Hiện tại, ứng dụng của nhóm là SportFields đang ở giai đoạn đầu với một domain duy nhất, quy mô dữ liệu và người dùng nằm trong tầm kiểm soát. Các module (Web, API, Database) tương tác với nhau liên tục, do đó việc đặt tất cả trong một Single-VPC giúp tối ưu hóa độ trễ và tiết kiệm chi phí băng thông, thay vì phải duy trì Peering hay Transit Gateway. 

Để đáp ứng tiêu chuẩn Production-ready, chúng tôi đã đưa toàn bộ hạ tầng mạng lên kiến trúc **Multi-AZ**. Các phân lớp mạng (Public, Private App, Private Data) đều được rải đều trên ít nhất 2 Availability Zones, đảm bảo tính sẵn sàng cao (High Availability) nếu có sự cố xảy ra ở cấp độ Data Center.

## 2. Các "Event kiến trúc" kích hoạt việc tạo VPC thứ 2
Trong tương lai, VPC thứ 2 hoặc thứ 3 sẽ được khởi tạo khi hệ thống gặp phải các sự kiện sau:

1. **Tách biệt môi trường (Environment Isolation):** Đây là ưu tiên hàng đầu. Khi dự án bước vào giai đoạn Production chính thức, chúng tôi bắt buộc phải tách biệt hoàn toàn môi trường Production và Dev/Staging để tránh sai sót cấu hình ở Dev làm sập hệ thống thật. Môi trường Production sẽ được cấp phát ở một VPC thứ 2 hoàn toàn riêng biệt.
2. **Yêu cầu về tuân thủ/bảo mật (Strict Security):** Khi tích hợp module thanh toán yêu cầu chứng chỉ PCI DSS, module đó phải được cô lập hoàn toàn trong một VPC riêng biệt với các lớp bảo mật khắt khe hơn.
3. **Cô lập tầng dữ liệu (Data Isolation):** Nếu ứng dụng mở rộng quy mô với lượng dữ liệu người dùng cực lớn, chúng tôi sẽ tách riêng tầng Application và tầng Database ra 2 VPC khác nhau. Việc này giúp áp dụng các chính sách bảo mật tầng mạng (Network ACLs, Security Groups) chuyên biệt cho Database, giảm thiểu rủi ro tấn công leo thang từ tầng Web.

*Lưu ý:* Nhờ việc đã quản lý cơ sở hạ tầng mạng bằng công cụ **Infrastructure as Code (Terraform)**, khi tạo thêm VPC thứ hai hoặc thứ ba, chúng tôi không cần phải cấu hình lại mọi thứ bằng tay từ đầu. Chỉ cần nhân bản module Terraform và thay đổi các tham số đầu vào (như CIDR block), hệ thống sẽ tự động triển khai kiến trúc chuẩn đã được kiểm chứng này sang môi trường mới một cách đồng nhất.

## 3. Bằng chứng Multi-AZ (Route Table)

![Route tables overview](evidence/MH1/01-route-tables-overview.png)

Ảnh trên cho thấy VPC `sportfields-dev-vpc` có các route table tách theo từng tầng mạng:

- `sportfields-dev-public-rt`
- `sportfields-dev-public-nat-rt-1`
- `sportfields-dev-private-app-rt-1`
- `sportfields-dev-private-app-rt-2`
- `sportfields-dev-private-data-rt-1`
- `sportfields-dev-private-data-rt-2`
- `sportfields-dev-firewall-rt`

`private-app-rt-1` phục vụ AZ-a, `private-app-rt-2` phục vụ AZ-b. Cách tách route table theo AZ giúp mỗi private app subnet có route riêng tới đúng firewall endpoint trong cùng AZ.

![Public route table routes](evidence/MH1/02-public-route-table-routes.png)

Public route table `sportfields-dev-public-rt` có route:

```text
0.0.0.0/0    -> igw-0721b44bfd8d2e511
10.30.0.0/16 -> local
```

![Public route table subnet associations](evidence/MH1/03-public-route-table-subnet-associations.png)

Public route table được associate với 2 public subnet ở 2 AZ:

1. `subnet-024ee1f4bc99924db`
   - Tên: `sportfields-dev-public-1`
   - AZ: `us-east-1a`
   - CIDR: `10.30.0.0/24`

2. `subnet-0175f422c8721a718`
   - Tên: `sportfields-dev-public-2`
   - AZ: `us-east-1b`
   - CIDR: `10.30.1.0/24`

![Resource map public subnet AZ-a](evidence/MH1/04-resource-map-public-az-a.png)

![Resource map public subnet AZ-b](evidence/MH1/05-resource-map-public-az-b.png)

- **Note:** Bảng định tuyến cho thấy các lưu lượng nội bộ được định tuyến chính xác giữa các Subnet thuộc nhiều AZ khác nhau.

## 4. Bằng chứng VPC Flow Logs
VPC Flow Logs đã được bật cho toàn bộ hệ thống và được cấu hình publish thẳng về hệ thống **CloudWatch Logs** (hoặc S3) để phân tích lưu lượng.

![VPC Flow Logs configuration](evidence/MH1/06-vpc-flow-log-config.png)

Cấu hình Flow Logs:

```text
Flow Log ID: fl-068d4c77b45db26e4
Name: sportfields-dev-vpc-flow-logs
State: Active
Destination type: cloud-watch-logs
Destination name: /aws/vpc-flow-logs/sportfields-dev
Traffic type: All
Max aggregation interval: 10 minutes
Log format: Default
```


- **Sample Log Entry:**

```text
2 529715002875 eni-0472392bae7999168 10.30.11.193 10.30.20.106 36326 5432 6 16 2251 1778816712 1778816731 ACCEPT OK
```

![VPC Flow Logs ACCEPT sample](evidence/MH1/08-vpc-flow-log-accept-sample.png)

- **Note:** Sample log trên cho thấy một kết nối hợp lệ được phép đi qua Network Interface, minh chứng cho việc hệ thống mạng đang được quan sát và ghi nhận đúng cách.
