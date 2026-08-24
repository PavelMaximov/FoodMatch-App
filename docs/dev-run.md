# Running FoodMatch locally

Flutter configuration is injected at build time. Do not commit a real Supabase URL, anon key, or other project credentials. From `food_match`, run:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=API_BASE_URL=http://<pc-lan-ip>:4000
```

`SUPABASE_URL` must be the project root. Do not append `/auth/v1`, `/rest/v1`, or any other path.

Choose `API_BASE_URL` for the device running Flutter:

| Flutter target | Backend URL |
| --- | --- |
| Physical Android device | `http://<PC_LAN_IP>:4000` |
| Android emulator | `http://10.0.2.2:4000` |
| Web or desktop on the backend machine | `http://localhost:4000` |

The phone and development computer must be on the same network when using a physical device. The backend must listen on `0.0.0.0`, but clients must use the computer's LAN IP rather than `0.0.0.0`.
