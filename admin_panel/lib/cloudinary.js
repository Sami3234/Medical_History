export const CLOUDINARY_CLOUD_NAME = process.env.NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME || '';
export const CLOUDINARY_API_KEY = process.env.NEXT_PUBLIC_CLOUDINARY_API_KEY || '';
export const CLOUDINARY_UPLOAD_PRESET = process.env.NEXT_PUBLIC_CLOUDINARY_UPLOAD_PRESET || '';

/**
 * Upload an image file directly to Cloudinary
 * @param {File} file - The file selected by the user
 * @param {string} folder - Destination folder on Cloudinary
 * @returns {Promise<{success: boolean, url?: string, publicId?: string, error?: string}>}
 */
export async function uploadToCloudinary(file, folder = 'medical_history/admin') {
  try {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('upload_preset', CLOUDINARY_UPLOAD_PRESET);
    formData.append('folder', folder);

    const res = await fetch(`https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload`, {
      method: 'POST',
      body: formData,
    });

    const data = await res.json();

    if (res.ok && data.secure_url) {
      return {
        success: true,
        url: data.secure_url,
        publicId: data.public_id,
      };
    } else {
      // If custom preset not found, try default ml_default
      if (CLOUDINARY_UPLOAD_PRESET !== 'ml_default') {
        const fallbackData = new FormData();
        fallbackData.append('file', file);
        fallbackData.append('upload_preset', 'ml_default');
        fallbackData.append('folder', folder);

        const fallbackRes = await fetch(`https://api.cloudinary.com/v1_1/${CLOUDINARY_CLOUD_NAME}/image/upload`, {
          method: 'POST',
          body: fallbackData,
        });

        const fallbackJson = await fallbackRes.json();
        if (fallbackRes.ok && fallbackJson.secure_url) {
          return {
            success: true,
            url: fallbackJson.secure_url,
            publicId: fallbackJson.public_id,
          };
        }
      }

      return {
        success: false,
        error: data.error?.message || `Upload failed with HTTP ${res.status}`,
      };
    }
  } catch (err) {
    return {
      success: false,
      error: err.message || 'Network error during upload',
    };
  }
}
