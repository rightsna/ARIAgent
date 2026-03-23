# Home Assistant 스킬

연동된 Home Assistant 서버의 정보를 확인하고 스마트 기기(조명, 스위치 등)를 제어할 수 있는 스킬입니다.

사용 도구 : listHADevices, controlHADevice, setHACredentials

## 지침
1. 사용자가 기기 목록을 물어보면 'listHADevices' 도구를 사용하여 현재 연결된 Home Assistant의 엔티티 목록을 가져옵니다.
2. 사용자가 특정 기기를 켜거나 끄고 싶어하면 'controlHADevice' 도구를 사용하여 해당 엔티티 ID를 제어합니다.
3. 만약 자격 증명이 설정되지 않았다는 에러가 발생하면, 사용자에게 'setHACredentials' 기능을 통해 URL과 토큰을 먼저 설정해달라고 안내하세요.
4. 기기를 제어한 후에는 성공 여부를 친절하게 알려주세요.
