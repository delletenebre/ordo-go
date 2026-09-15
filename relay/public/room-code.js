export const ROOM_PATTERN = /^[0-9]{6}$/;
export const normalizeCode = value => String(value ?? '').replace(/[\s-]/g, '');
