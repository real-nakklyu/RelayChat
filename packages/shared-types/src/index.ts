export type UUID = string;

export type PrivacyAudience = "everyone" | "contacts" | "nobody";
export type EmailVisibility = "hidden" | "everyone" | "contacts";
export type ContactRequestStatus = "pending" | "accepted" | "rejected" | "cancelled";
export type MessageDeliveryStatus = "sent" | "delivered" | "read";
export type AttachmentKind = "image" | "file";

export interface Profile {
  id: UUID;
  username: string;
  display_name: string | null;
  avatar_path: string | null;
  bio: string | null;
  created_at: string;
  updated_at: string;
}

export interface PrivacySettings {
  user_id: UUID;
  email_visibility: EmailVisibility;
  last_seen_visibility: PrivacyAudience;
  profile_photo_visibility: PrivacyAudience;
}

export interface ContactRequest {
  id: UUID;
  requester_id: UUID;
  addressee_id: UUID;
  status: ContactRequestStatus;
  created_at: string;
  updated_at: string;
}

export interface Conversation {
  id: UUID;
  kind: "direct";
  created_at: string;
  updated_at: string;
}

export interface Message {
  id: UUID;
  conversation_id: UUID;
  sender_id: UUID;
  body: string | null;
  delivery_status: MessageDeliveryStatus;
  edited_at: string | null;
  deleted_for_everyone_at: string | null;
  created_at: string;
}

export interface MessageAttachment {
  id: UUID;
  message_id: UUID;
  uploader_id: UUID;
  storage_bucket: string;
  storage_path: string;
  file_name: string;
  mime_type: string;
  size_bytes: number;
  kind: AttachmentKind;
  created_at: string;
}
