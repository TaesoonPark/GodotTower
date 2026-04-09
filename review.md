# GodotTower 프로젝트 코드 리뷰

## 1. 프로젝트 개요

**프로젝트명**: ColonySimPrototype  
**엔진**: Godot 4.6  
**장르**: Colony Simulation / RTS (Real-Time Strategy)  
**월드 크기**: 7680 x 4320 타일 (타일 크기: 40px)

이 프로젝트는 Settlement Colonization 방식의 타워 디펜스+RTS 혼합 게임으로, 입주민(Colonist)들을 관리하여 생존하고 적의 공격을 막는 것이 핵심 목표다.

---

## 2. 아키텍처 개요

### 2.1 계층 구조

```
┌─────────────────────────────────────────────────┐
│            MainController (3821 lines)          │
│  - 게임 상태 관리, 리소스, 레이드, 연구, HUD     │
└─────────────────────────────────────────────────┘
         │          │          │          │
    ┌────▼────┐ ┌───▼──┐ ┌────▼────┐ ┌──▼────┐
    │JobSystem│ │Build │ │ Need   │ │Input  │
    │ (1132)  │ │System│ │System  │ │Controller│
    └─────────┘ │(281) │ │  (16)  │ └────────┘
                └──────┘ └────────┘
```

### 2.2 핵심 시스템

| 시스템 | 라인 수 | 역할 |
|--------|---------|------|
| **MainController** | 3821 | 전체 게임 컨트롤, 리소스 관리, 레이드 조정, 연구 진행 |
| **JobSystem** | 1132 | 작업 할당, 우선순위 관리, 제작 큐, 공격 명령 |
| **BuildSystem** | 281 | 건물 배치, 블루프린트, 비용 계산, 건설 사이트 |
| **Colonist** | 1292 | 입주민 AI, 이동, 전투, 채집, 제작, 상태 관리 |
| **Zombie** | 405 | 좀비 적대 유닛, 타겟팅, 공격, 구조물 파괴 |
| **Raider** | 431 | 강도 적대 유닛, 전투 패턴 |
| **HUDController** | 1219 | UI 컨트롤, 패널 표시, 리소스 UI |
| **FarmZone** | 438 | 농업 구역, 작물 재배, 성장 관리 |
| **PathingOccupancy** | 129 | 경로 점유 관리, 충돌 회피 |

---

## 3. 데이터 시스템

### 3.1 데이터 정의 스크립트

프로젝트는 Resource 기반의 데이터-Driven 아키텍처를採用한다:

- **BuildingDef** (`scripts/data/BuildingDef.gd`): 건물 정의
- **RecipeDef** (`scripts/data/RecipeDef.gd`): 레시피/제작 정의
- **CropDef** (`scripts/data/CropDef.gd`): 작물 정의
- **ResearchDef** (`scripts/data/ResearchDef.gd`): 연구 정의
- **WorkstationDef** (`scripts/data/WorkstationDef.gd`): 작업대 정의
- **ResourceDef** (`scripts/data/ResourceDef.gd`): 자원 정의
- **ColonistStatsData** (`scripts/data/ColonistStatsData.gd`): 입주민 스탯
- **ColonistLoadoutData** (`scripts/data/ColonistLoadoutData.gd`): 장비
- **JobPriorityData** (`scripts/data/JobPriorityData.gd`): 작업 우선순위

### 3.2 데이터 리소스 (51개 .tres 파일)

| 디렉토리 | 파일 수 | 내용 |
|----------|---------|------|
| `data/buildings/` | 18 | Stockpile, Wall, Gate, Farm, ResearchBench 등 |
| `data/recipes/` | 10 | 요리, 제작 레시피 |
| `data/resources/` | 14 | Wood, Stone, Steel, Food, Weapon 등 |
| `data/crops/` | 1 | 감자 |
| `data/research/` | 17 | 연구 프로젝트 |
| `data/workstations/` | 2 | 작업대 |
| `data/colonists/` | 2 | 입주민 기본 데이터 |
| `data/priorities/` | 1 | 작업 우선순위 기본값 |

---

## 4. 핵심 기능 분석

### 4.1 입주민 시스템 (Colonist.gd)

**주요 속성**:
- health, hunger, rest, mood (needs 시스템)
- combat_profile: 전투 능력치 (hit chance, defense, attack, range)
- equipment_slots: 장비 (Top, Bottom, Hat, Weapon)
- work_enabled: 작업 활성화 플래그

**행동 상태 머신**:
1. Idle - 대기
2. MoveTo - 이동
3. BuildSite - 건설
4. Haul - 운반
5. Craft - 제작
6. Gather - 채집
7. Hunt - 사냥
8. CombatMelee / CombatRanged - 전투
9. RepairStructure - 수리
10. Demolish - 해체

### 4.2 적대 유닛 (Zombie.gd, Raider.gd)

**Zombie**:
- health: 165, move_speed: 78, base_hit: 0.56
- 구조물 공격 가능 (structure_attack_damage: 16)
- 근접 공격만 지원

**Raider**:
- 좀비보다 강화된 전투 능력
- 드물게 장비를.Drop

### 4.3 작업 시스템 (JobSystem.gd)

작업 할당 알고리즘:
- 우선순위 기반 할당 (base_priority)
- 작업 타입별 스캔 및 매칭
- 제작 큐 관리 (workstation별)
- 레이드 모드: 모든 입주민Combat 상태 전환

### 4.4 농업 시스템 (FarmZone.gd)

- 작물 유형 선택 가능
- 성장 시간, 수확량, fertility 관리
- nearby建筑物로부터 growth_bonus, yield_bonus 지원

### 4.5 전투 시스템 (CombatMath.gd)

- 명중률 계산: base_hit + accuracy_bonus - target_defense
- 피해 계산: attack - defense + armor_penetration
- 커버 시스템: cover_bonus 제공

### 4.6 레이드 시스템

MainController에서 관리:
- `_raid_state`: Idle → Warning → Active
- `_raid_wave_size`:一波规模
- `_raid_wave_kind`: RaiderOnly / ZombieMix
- 레이드 보상: 연구 포인트, 자원

### 4.7 연구 시스템

- 연구 대开展工作대 필요
- `_research_completed`: 완료된 연구 ID 집합
- 연구 보너스:
  - `_build_speed_bonus_from_research`
  - `_farm_yield_bonus_from_research`
  - `_combat_accuracy_bonus_from_research` 등

---

## 5. 씬 (Scene) 구조

### 5.1 Main.tscn
- Camera2D
- WorldRoot (게임월드)
- UnitsRoot (유닛들)
- Systems (InputController, NeedSystem, JobSystem, BuildSystem)
- HUD

### 5.2 Units
- `Colonist.tscn`: 입주민 유닛
- `Zombie.tscn`: 좀비
- `Raider.tscn`: 강도

### 5.3 World
- `World.tscn`: 게임월드 기본
- `BuildingSite.tscn`: 건설 사이트 (블루프린트)
- `FarmZone.tscn`: 농업 구역
- `StockpileZone.tscn`: 저장 구역
- `Gatherable.tscn`: 채집 가능한 자원
- `Huntable.tscn`: 사냥 가능한 동물
- `ResourceDrop.tscn`:地面上 떨어진 자원

---

## 6. 기술적 특징

### 6.1 성능 최적화 기법

1. **LOD (Level of Detail)**: Colonist/Zombie의 물리 처리 간격 조절
   - Near: 0.02초 간격
   - Far: 0.16초 간격

2. **공간 캐싱**: `_spatial_cache_dirty` 플래그로 불필요한 스캔 최소화

3. **Pathing Occupancy**: 경로 점유를 Revision 기반으로 관리

4. **디스패치 시스템**: `_dispatch_*_dirty` 플래그로 작업 처리 순서 최적화

### 6.2 입력 처리

- EDGE_SCROLL_MARGIN: 화면 가장자리로 카메라 이동
- ZOOM_STEP: 줌 단계 (0.65 ~ 1.85)
- 작업 디스패치 배치

---

## 7. 파일 통계

| 종류 | 파일 수 | 총 라인 수 |
|------|---------|------------|
| 스크립트 (.gd) | 28 | ~10,200 |
| 씬 (.tscn) | 14 | - |
| 리소스 (.tres) | 74 | - |
| **전체** | **116** | **~10,200** |

---

## 8. 주요 데이터 흐름

```
MainController.tick()
  ├─ JobSystem.process_dirty()
  │   ├─ request_haul_jobs()
  │   ├─ request_build_jobs()
  │   ├─ request_craft_jobs()
  │   ├─ request_combat_jobs()
  │   └─ assign_jobs()
  │
  ├─ BuildSystem.update()
  │   ├─ _check_build_completion()
  │   └─ _update_site_work()
  │
  ├─ Colonist.tick()
  │   ├─ tick_needs()      // 식사, 휴식, 기분
  │   ├─ _process_movement()
  │   ├─ update_job_completion()
  │   └─ _process_active_work()
  │
  ├─ Enemy.tick()
  │   ├─ _ai_tick()        // 타겟 선택, 공격
  │   └─ _process_movement()
  │
  └─ FarmZone.tick()
      └─ _grow_crops()
```

---

## 9. 향후 개선 가능 영역

1. **코드 분리**: MainController (3821줄) 너무 큼 → 서브 시스템으로 분산 필요
2. **이벤트 시스템**: 시그널 의존도가 높음 → 중앙 이벤트 버스 고려
3. **테스트 코드**: `scripts/tests/` 디렉토리에 테스트 파일 부재
4. **모듈화**: 데이터 정의와 로직 분리가 명확하나, 일부 로직 중복 존재
5. **문서화**: 스크립트 내 주석 부족, AGENTS.md 부재

---

## 10. 결론

GodotTower는 상당히 완성도 높은 Colony Simulation + RTS 게임이다:
- 자원 관리, 제작, 농업, 연구, 전투 등 다양한 시스템이 유기적으로 연결됨
- Resource 기반 데이터-Driven 아키텍처로 확장성 확보
- LOD와 캐싱을 활용한 성능 최적화 구현
- 다만 중앙 컨트롤러의 크기가 크고, 테스트 파일이 부족한 것이 아쉬움
