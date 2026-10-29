"""Local upload references must be bound to the user who uploaded them."""

import unittest

from src.local_uploads import new_local_upload_reference, require_owned_local_upload


class LocalUploadOwnerTests(unittest.TestCase):
    def test_owner_can_reuse_their_uploaded_video(self):
        filename, reference = new_local_upload_reference("creator-a", ".mp4")

        self.assertEqual(reference, f"upload://{filename}")
        self.assertEqual(require_owned_local_upload(reference, "creator-a"), filename)

    def test_another_user_cannot_submit_the_reference(self):
        _, reference = new_local_upload_reference("creator-a", ".mp4")

        with self.assertRaisesRegex(ValueError, "does not belong"):
            require_owned_local_upload(reference, "creator-b")

    def test_references_with_paths_or_unowned_legacy_names_are_rejected(self):
        _, reference = new_local_upload_reference("creator-a", ".mp4")
        for invalid in ("upload://old-video.mp4", reference.replace("upload://", "upload://../"),
                        reference + "/extra", reference + "?query=1", "upload://s3/owner/video.mp4"):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                require_owned_local_upload(invalid, "creator-a")

    def test_generated_references_have_distinct_names(self):
        first, _ = new_local_upload_reference("creator-a", ".mp4")
        second, _ = new_local_upload_reference("creator-a", ".mp4")
        self.assertNotEqual(first, second)


if __name__ == "__main__":
    unittest.main()
