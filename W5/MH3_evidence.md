# MH3 Evidence Pack - File Storage + Backup Plan

Project: SportFields / TopJob deployment  
AWS account: `529715002875`  
Region: `us-east-1`  
VPC: `sportfields-dev-vpc` / `vpc-03fee4bca2c513e22`  
Must-have: **MH3 - File Storage Layer + Backup Plan**

## Quyết định

Project này dùng **Amazon EFS Regional** làm lớp shared file storage cho backend app tier.

Lý do chọn EFS:

- Backend chạy trên Linux EC2 trong private application subnet.
- App cần shared file storage dạng NFS để nhiều app instance có thể cùng truy cập khi scale.
- Nội dung lưu trên EFS là dữ liệu thật của ứng dụng: admin system report JSON được generate từ database live, gồm users, fields, bookings, payments, reviews và revenue.
- FSx không phù hợp hơn trong case này vì app không cần Windows SMB, Lustre/HPC, NetApp ONTAP hoặc OpenZFS.

Luồng sử dụng file storage:

```text
Admin Dashboard
-> Backend admin API
-> Generate system report from live RDS data
-> Write JSON to /mnt/sportfields-shared/evidence/
-> Read JSON back through mounted EFS path
```

## 1. Bằng chứng EFS file system

Screenshot cần có:

- Trang EFS file system details hiển thị file system ID, state và encryption.

![EFS file system details](evidence/mh3/01-efs-file-system-details.png)

Cấu hình quan sát được:

```text
File system ID: fs-02cab5360e947d5ac
Name: sportfields-dev-shared-efs
Type: Regional EFS
State: available
Encrypted: true
Performance mode: generalPurpose
Throughput mode: elastic
Mount path on backend EC2: /mnt/sportfields-shared
```

Ghi chú:

EFS Regional được dùng để cung cấp file storage dùng chung cho app tier, thay vì lưu file cục bộ trên từng EC2 instance.

## 2. Bằng chứng mount targets trong private app subnets

Screenshot cần có:

- EFS > File systems > `fs-02cab5360e947d5ac` > Network / Mount targets.
- Hiển thị 2 mount targets ở 2 AZ.

![EFS mount targets](evidence/mh3/02-efs-mount-targets.png)

Mount targets:

| Availability Zone | Subnet | Subnet name | Mount target state |
| --- | --- | --- | --- |
| `us-east-1a` | `subnet-06925c3f4054bd952` | `sportfields-dev-private-app-1` | available |
| `us-east-1b` | `subnet-0b11d62d69b8d3cf1` | `sportfields-dev-private-app-2` | available |

Evidence bổ sung:

- VPC subnet details cho private app subnets, thể hiện `MapPublicIpOnLaunch = false`.
- Nếu không có screenshot subnet riêng, screenshot backend EC2 private instance ở mục 3 đã đủ để chứng minh EC2 app tier không có public IPv4 và nằm trong private app subnet.

Ghi chú:

EFS mount targets được đặt trong private application subnets, không đặt trong public subnet. Điều này đúng với yêu cầu "mount lên EC2/Lambda trong private application subnet".

## 3. Bằng chứng security group của EFS mount target

Screenshot cần có:

- EC2 > Security Groups > `sg-01a9505e5633db5ed`.
- Inbound rule chỉ allow TCP `2049` từ app tier SG.

![EFS security group inbound rule](evidence/mh3/04-efs-security-group-inbound.png)

Cấu hình quan sát được:

```text
EFS SG: sg-01a9505e5633db5ed / sportfields-dev-efs-sg
Inbound:
- Type: NFS
- Protocol: TCP
- Port: 2049
- Source: sg-0cc247a1ec599dc89 / sportfields-dev-ec2-sg
No inbound rule from 0.0.0.0/0
```

Screenshot bổ sung cần có:

- EC2 instance details của backend instance.

![Backend EC2 private instance](evidence/mh3/05-backend-ec2-private-instance.png)

Backend app instance:

```text
Instance ID: i-04cc7c8158b146415
Name: sportfields-dev-backend
Subnet: subnet-06925c3f4054bd952 / sportfields-dev-private-app-1
Security group: sg-0cc247a1ec599dc89 / sportfields-dev-ec2-sg
Public IPv4 address: none
```

Ghi chú:

Mount target SG chỉ cho phép NFS từ app tier SG, không mở public access. Backend EC2 đang chạy trong private subnet và không có public IP.

## 4. Bằng chứng app ghi và đọc file thật từ EFS

Screenshot cần có:

- Admin dashboard hiển thị EFS report đã được tạo.

![Admin dashboard EFS report](evidence/mh3/06-admin-dashboard-efs-report.png)

File report do app tạo:

```text
Relative path: evidence/mh3-admin-system-report-2026-05-14T17-16-47-764Z.json
Mounted path: /mnt/sportfields-shared
Full original path:
/mnt/sportfields-shared/evidence/mh3-admin-system-report-2026-05-14T17-16-47-764Z.json
```

Data thật trong report:

| Metric | Value |
| --- | --- |
| Users | `6` |
| Fields | `2` |
| Bookings | `3` |
| Revenue | `1,748,000 VND` |

Evidence terminal / SSM:

Lệnh kiểm chứng:

```bash
mountpoint /mnt/sportfields-shared
sudo cat /mnt/sportfields-shared/evidence/mh3-admin-system-report-2026-05-14T17-16-47-764Z.json | head -40
```

Kết quả cần thấy:

```text
/mnt/sportfields-shared is a mountpoint
"type": "mh3-efs-admin-system-report"
"environment": "production"
"summary"
```

Ghi chú:

Đây không phải marker file rời. Backend admin API generate report từ dữ liệu live trong database rồi ghi vào EFS. UI đọc lại report này qua backend.

## 5. Bằng chứng AWS Backup plan

Screenshot cần có:

- AWS Backup > Backup plans > `sportfields-dev-w5-backup-plan`.
- Hiển thị rule, vault, schedule và retention.

![Backup plan rule](evidence/mh3/08-backup-plan-rule.png)

Cấu hình backup plan:

```text
Backup plan: sportfields-dev-w5-backup-plan
Backup plan ID: 121734e8-4fb7-4a86-9871-8904ecb71df9
Rule: daily-retain-7-days
Vault: sportfields-dev-w5-vault
Schedule: cron(0 18 * * ? *) / daily
Retention: 7 days
```

Backup selection:

```text
Selection: sportfields-dev-w5-tagged-resources
IAM role: arn:aws:iam::529715002875:role/sportfields-dev-backup-role
Tag condition:
- Backup = sportfields-w5
```

Ghi chú:

Backup plan dùng tag selection để bao trùm các resource stateful của W5. Rule chạy daily và giữ recovery points tối thiểu 7 ngày, đúng yêu cầu project.

## 6. Bằng chứng backup jobs và recovery points

Evidence backup jobs:

- AWS Backup > Jobs > Backup jobs.
- Hiển thị completed backup jobs cho EFS, RDS, EBS.
- Nếu không có screenshot backup jobs riêng, screenshot recovery points ở vault trong mục này vẫn chứng minh backup đã completed cho EFS/RDS/EBS.

Backup jobs đã completed:

| Resource type | Resource | Status |
| --- | --- | --- |
| EFS | `fs-02cab5360e947d5ac` | COMPLETED |
| RDS | `sportfields-dev-postgres` | COMPLETED |
| EBS | `vol-095f4428330d3e062` | COMPLETED |

Screenshot recovery points cần có:

- AWS Backup > Backup vaults > `sportfields-dev-w5-vault` > Recovery points.
- Hiển thị recovery points cho EFS, RDS, EBS.

![Recovery points for EFS RDS EBS](evidence/mh3/12-recovery-points-efs-rds-ebs.png)

Recovery point resources:

```text
EFS:
arn:aws:elasticfilesystem:us-east-1:529715002875:file-system/fs-02cab5360e947d5ac

RDS:
arn:aws:rds:us-east-1:529715002875:db:sportfields-dev-postgres

EBS:
arn:aws:ec2:us-east-1:529715002875:volume/vol-095f4428330d3e062
```

Ghi chú:

Vault `sportfields-dev-w5-vault` có recovery points completed cho đủ ba loại resource trong stack: file system, database W3 và EBS volume W2.

## 7. Bằng chứng restore test Completed

Screenshot cần có:

- AWS Backup > Jobs > Restore jobs.
- Hiển thị restore job `25de49d4-2f66-4ccf-8322-f293a45bd10e` Completed.

![Restore job completed](evidence/mh3/13-restore-job-completed.png)

Restore job dùng cho evidence:

```text
Restore job ID: 25de49d4-2f66-4ccf-8322-f293a45bd10e
Resource type: EFS
Resource ID: file-system/fs-02cab5360e947d5ac
Status: Completed
Completion time: 2026-05-15 00:27:00 +07
```

Ghi chú về job failed:

```text
Restore job 1c6c261b-0008-4de8-b61a-6a334fe2eba8 failed because it used an older recovery point created before the admin report file existed. The valid restore evidence is job 25de49d4-2f66-4ccf-8322-f293a45bd10e, which restored from a newer EFS recovery point that contained the report.
```

## 8. Bằng chứng data đọc được từ resource đã restore

Screenshot terminal / SSM cần có:

![Restored report readable](evidence/mh3/14-restored-report-readable.png)

Lệnh kiểm chứng:

```bash
sudo cat /mnt/sportfields-shared/aws-backup-restore_2026-05-14T17-27-00-417720408Z/evidence/mh3-admin-system-report-2026-05-14T17-16-47-764Z.json | head -60
```

Path restored file:

```text
/mnt/sportfields-shared/aws-backup-restore_2026-05-14T17-27-00-417720408Z/evidence/mh3-admin-system-report-2026-05-14T17-16-47-764Z.json
```

Kết quả cần thấy trong screenshot:

```json
{
  "type": "mh3-efs-admin-system-report",
  "environment": "production",
  "sharedStoragePath": "/mnt/sportfields-shared",
  "relativePath": "evidence/mh3-admin-system-report-2026-05-14T17-16-47-764Z.json",
  "summary": {
    "users": {
      "total": 6
    },
    "fields": {
      "total": 2
    },
    "bookings": {
      "total": 3
    },
    "revenue": {
      "paidBookingTotal": 1748000
    }
  }
}
```

Ghi chú:

AWS Backup restore EFS không overwrite destructively. Restore job tạo thư mục `aws-backup-restore_*` trong file system. Backend EC2 trong private app subnet đọc được report JSON từ thư mục restore đó, chứng minh restore test có data thật và data đọc được.

## Kết luận MH3

MH3 đã hoàn thành vì:

- EFS Regional đã được tạo và mount vào backend EC2 trong private app subnet.
- EFS mount target SG chỉ allow TCP 2049 từ app tier SG, không allow `0.0.0.0/0`.
- Backend app ghi và đọc file report thật từ `/mnt/sportfields-shared`.
- AWS Backup plan có schedule daily, retention 7 ngày và vault riêng.
- Backup vault có recovery points completed cho EFS, RDS và EBS.
- Restore job EFS `25de49d4-2f66-4ccf-8322-f293a45bd10e` completed.
- Data từ restore path `aws-backup-restore_*` đọc được thành công trên EC2 app tier.

Final statement:

```text
SportFields satisfies MH3. The application uses Amazon EFS as shared storage for the private backend app tier, writes meaningful admin report data to the mounted path, protects EFS/RDS/EBS through AWS Backup, and has a completed EFS restore test with readable restored application data.
```
