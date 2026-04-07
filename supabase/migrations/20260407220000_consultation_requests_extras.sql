-- Campos extendidos para solicitud de consulta (modalidad, prioridad, JSON de detalle).

ALTER TABLE public.consultation_requests ADD COLUMN IF NOT EXISTS modality VARCHAR(20);
ALTER TABLE public.consultation_requests ADD COLUMN IF NOT EXISTS priority VARCHAR(20);
ALTER TABLE public.consultation_requests ADD COLUMN IF NOT EXISTS antecedentes TEXT;
ALTER TABLE public.consultation_requests ADD COLUMN IF NOT EXISTS details_json JSONB;
