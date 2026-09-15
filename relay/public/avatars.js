export const AVATARS = {
  manas: 'Манас', kanykei: 'Каныкей', bakai: 'Бакай', semetei: 'Семетей',
  aichurok: 'Айчүрөк', almambet: 'Алмамбет', ilbirs: 'Илбирс', bugu: 'Бугу',
  saikal: 'Сайкал', janyl: 'Жаңыл Мырза', akshumkar: 'Акшумкар', tulpar: 'Тулпар',
};
export const avatarId = (value, fallback = 'manas') => Object.hasOwn(AVATARS, value) ? value : fallback;
