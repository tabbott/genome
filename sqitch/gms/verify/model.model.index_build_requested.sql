-- Verify model.model.index_build_requested

BEGIN;

SELECT 1/count(*) FROM pg_class WHERE relkind = 'i' and relname = 'm_m_build_requested_index';

ROLLBACK;
