const { Router } = require('express');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const ctrl = require('../controllers/staffController');
const { verifyToken, requireRole } = require('../middleware/auth');
const { branchAccess } = require('../middleware/branchAccess');

const router = Router();
router.use(verifyToken, branchAccess);

const staffPhotoDir = path.join(__dirname, '..', 'uploads', 'staff');
fs.mkdirSync(staffPhotoDir, { recursive: true });
const photoStorage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, staffPhotoDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    cb(null, `staff-${req.params.id}-${Date.now()}${ext || '.jpg'}`);
  },
});
const photoUpload = multer({
  storage: photoStorage,
  limits: { fileSize: 3 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if ((file.mimetype || '').startsWith('image/')) return cb(null, true);
    return cb(new Error('Only image files are allowed'));
  },
});

router.get('/',                         ctrl.list);
router.get('/commission',               ctrl.commissionSummary);
router.get('/me/commission',            ctrl.myCommission);
router.get('/:id',                      ctrl.getOne);
router.post('/',                        requireRole('superadmin', 'admin', 'manager'), ctrl.create);
router.put('/:id',                      requireRole('superadmin', 'admin', 'manager'), ctrl.update);
router.post('/:id/photo',               requireRole('superadmin', 'admin', 'manager'), photoUpload.single('photo'), ctrl.setPhoto);
router.delete('/:id/photo',             requireRole('superadmin', 'admin', 'manager'), ctrl.removePhoto);
router.delete('/:id',                   requireRole('superadmin', 'admin'), ctrl.remove);
router.get('/:id/commission',           ctrl.commissionReport);
router.post('/:id/specializations',     requireRole('superadmin', 'admin', 'manager'), ctrl.setSpecializations);

module.exports = router;
