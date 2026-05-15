const fs = require('fs/promises');
const path = require('path');
const { Op } = require('sequelize');
const {
  User,
  Field,
  SubField,
  Booking,
  Payment,
  Review
} = require('../models');
const { successResponse, errorResponse } = require('../common/responses/apiResponse');
const { USER_ROLES } = require('../common/constants');

const DEFAULT_SHARED_STORAGE_PATH = path.resolve(__dirname, '../../storage/shared');
const EVIDENCE_DIR = 'evidence';

const getSharedStoragePath = () => process.env.SHARED_STORAGE_PATH || DEFAULT_SHARED_STORAGE_PATH;

const getEvidenceDirectory = () => path.join(getSharedStoragePath(), EVIDENCE_DIR);

const buildEvidenceFilename = () => {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  return `mh3-admin-system-report-${timestamp}.json`;
};

const isSafeEvidenceFilename = (filename) => (
  typeof filename === 'string'
  && filename === path.basename(filename)
  && /^mh3-admin-system-report-[A-Za-z0-9._-]+\.json$/.test(filename)
);

const buildSystemSummary = async () => {
  const paidBookingFilter = {
    status: { [Op.or]: ['confirmed', 'completed'] },
    payment_status: { [Op.or]: ['paid', 'completed'] }
  };

  const [
    totalUsers,
    totalOwners,
    totalCustomers,
    totalFields,
    verifiedFields,
    pendingFields,
    totalSubFields,
    totalBookings,
    paidBookings,
    cancelledBookings,
    totalRevenue,
    totalPayments,
    succeededPayments,
    totalReviews
  ] = await Promise.all([
    User.count(),
    User.count({ where: { role: USER_ROLES.OWNER } }),
    User.count({ where: { role: USER_ROLES.CUSTOMER } }),
    Field.count(),
    Field.count({ where: { is_verified: true } }),
    Field.count({ where: { is_verified: false } }),
    SubField.count(),
    Booking.count(),
    Booking.count({ where: paidBookingFilter }),
    Booking.count({ where: { status: 'cancelled' } }),
    Booking.sum('total_price', { where: paidBookingFilter }),
    Payment.count(),
    Payment.count({ where: { status: 'succeeded' } }),
    Review.count()
  ]);

  return {
    users: {
      total: totalUsers,
      owners: totalOwners,
      customers: totalCustomers
    },
    fields: {
      total: totalFields,
      verified: verifiedFields,
      pending: pendingFields,
      subFields: totalSubFields
    },
    bookings: {
      total: totalBookings,
      paid: paidBookings,
      cancelled: cancelledBookings
    },
    payments: {
      total: totalPayments,
      succeeded: succeededPayments
    },
    reviews: {
      total: totalReviews
    },
    revenue: {
      paidBookingTotal: Number(totalRevenue || 0)
    }
  };
};

const createEvidenceReport = async (req, res) => {
  try {
    const evidenceDir = getEvidenceDirectory();
    await fs.mkdir(evidenceDir, { recursive: true });

    const filename = buildEvidenceFilename();
    const absolutePath = path.join(evidenceDir, filename);
    const summary = await buildSystemSummary();

    const report = {
      type: 'mh3-efs-admin-system-report',
      generatedAt: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      sharedStoragePath: getSharedStoragePath(),
      relativePath: path.join(EVIDENCE_DIR, filename),
      generatedBy: {
        id: req.user.id,
        email: req.user.email,
        role: req.user.role
      },
      summary
    };

    await fs.writeFile(absolutePath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');

    return successResponse(res, 'Tạo MH3 EFS evidence report thành công', {
      filename,
      relativePath: report.relativePath,
      sharedStoragePath: report.sharedStoragePath,
      summary
    }, 201);
  } catch (error) {
    console.error('Error creating MH3 EFS evidence report:', error);
    return errorResponse(res, 'Lỗi tạo MH3 EFS evidence report', 500, {
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

const getEvidenceReport = async (req, res) => {
  try {
    const { filename } = req.params;

    if (!isSafeEvidenceFilename(filename)) {
      return errorResponse(res, 'Tên file evidence không hợp lệ', 400);
    }

    const absolutePath = path.join(getEvidenceDirectory(), filename);
    const content = await fs.readFile(absolutePath, 'utf8');

    return successResponse(res, 'Đọc MH3 EFS evidence report thành công', {
      filename,
      relativePath: path.join(EVIDENCE_DIR, filename),
      report: JSON.parse(content)
    });
  } catch (error) {
    if (error.code === 'ENOENT') {
      return errorResponse(res, 'Không tìm thấy file evidence', 404);
    }

    console.error('Error reading MH3 EFS evidence report:', error);
    return errorResponse(res, 'Lỗi đọc MH3 EFS evidence report', 500, {
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

module.exports = {
  createEvidenceReport,
  getEvidenceReport
};
