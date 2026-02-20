// StorageService.swift
// Firebase Storage for avatar image uploads

import Foundation
import FirebaseStorage
import UIKit

final class StorageService {

    static let shared = StorageService()
    private init() {}

    private let storage = Storage.storage()

    // MARK: - Avatar Upload

    func uploadAvatar(uid: String, imageData: Data) async throws -> URL {
        // Compress image to max 512x512 JPEG
        guard let image = UIImage(data: imageData),
              let compressed = compressImage(image, maxSize: 512, quality: 0.8) else {
            throw StorageError.compressionFailed
        }

        let ref = storage.reference().child("avatars/\(uid)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(compressed, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        return downloadURL
    }

    // MARK: - Image Compression

    private func compressImage(_ image: UIImage, maxSize: CGFloat, quality: CGFloat) -> Data? {
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resized?.jpegData(compressionQuality: quality)
    }
}

enum StorageError: LocalizedError {
    case compressionFailed
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to process the image. Please try a different photo."
        case .uploadFailed:      return "Upload failed. Check your connection and try again."
        }
    }
}
