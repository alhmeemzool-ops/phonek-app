-- Keep the database message enum aligned with MessageType in chat_model.dart.
-- These values enable the offer, swap, and voice message flows.
ALTER TYPE public.message_type ADD VALUE IF NOT EXISTS 'offer';
ALTER TYPE public.message_type ADD VALUE IF NOT EXISTS 'swap';
ALTER TYPE public.message_type ADD VALUE IF NOT EXISTS 'voice';
