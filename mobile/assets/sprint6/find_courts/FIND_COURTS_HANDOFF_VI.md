# Sprint 6 — Find Courts Map: thông số và handoff

Nguồn duy nhất về thiết kế: https://www.figma.com/design/XSwsBDmz46CduUchU8k2KZ?node-id=469-1027
Đọc trực tiếp qua Figma MCP ngày 2026-10-14. Không sửa canvas, không sửa mã ứng dụng hoặc pubspec.yaml.
Đơn vị dưới đây là đơn vị thiết kế Figma. Tọa độ màn tính từ góc trên trái frame. Tọa độ con trong JSON là tương đối với parent.

## 1. Frame, vùng an toàn và thứ tự layer

Frame `469:1027`, tên **01 Find Courts Map**, 393 × 852, clipsContent=true; nằm tại (40,100) trong section Sprint 6, không phải tọa độ màn hình.
Nền #FAFBF9, không viền, radius=0.
Figma không khai báo OS safe-area inset: **Not determined from Figma**. Những vùng sau là hình vẽ/layout thực tế, không được đồng nhất với inset iOS:
- Status bar: (0,0),393×52; nền trắng. Giờ 9:41 tại (24,16),13/600,line18,#081812.
- Dynamic Island: (136.5,8),120×30,r15,#030806.
- Cụm sóng/Wi-Fi/pin: (299,17),70×18.
- Navigation: y768,h84; Home indicator (129.5,840),134×4,r2,#06130D.
- Độ cao chừa phía dưới của nav là padding22; không có dữ liệu khẳng định inset hệ thống34 hay top59.
**Khuyến nghị kỹ thuật, không phải thông số Figma:** dùng status bar/home indicator của hệ điều hành trên thiết bị thật; không vẽ thêm một bộ giả nếu OS đã hiển thị. Ánh xạ theo MediaQuery/SafeArea, tránh cộng inset hai lần.

Thứ tự vẽ từ dưới lên:
1. Map viewport (0,0),393×768.
2. Floating header (0,0),393×216.
3. Sheet host (0,192),393×576, phần trên trong suốt.
4. Navigation (0,768),393×84.
5. Home indicator.
6. Dot thông báo đã áp dụng filter tại (360,120),6×6, ẩn mặc định.
7. Search panel, Filter panel, Layers panel; đều ẩn mặc định.

## 2. Header nổi

Master `467:249`, instance `469:1030`. Header trong suốt; status bar trắng. Không có tiêu đề Explore/subtitle đang hiển thị trong bản này.
Explore Controls: (0,52),393×164; Auto Layout dọc, padding T/R/B/L=8/20/8/20,gap8.
- Segmented control: màn (20,60),353×44,r22,trắng. Hai tab 176.5×44. Find Courts nền#05644F,chữ trắng; Find Players nền trong suốt,chữ#647976. Label12/500,line17. Bóng S1.
- Search row: (20,112),353×44,gap8.
- Search field:301×44,r22,trắng, paddingLeft12,gap10, căn giữa dọc; icon18×18 tại(12,13); placeholder “Search court name or area”,13/400,line18,#8B9794 tại(40,13). Bóng S2.
- Filter button: màn(329,112),44×44,r22; icon20×20 tại(12,12). Trắng,bóng S2.
- Quick Filters: màn(20,164),353×44,clip=true, horizontal overflow, gap8,căn giữa dọc.
  - Within 5 km ⌄: touch104×44; pill104×32.
  - Open now:85×44; pill85×32.
  - Indoor:66×44; pill66×32.
  - Price ⌄:72×44; pill72×32.
  - x nội bộ lần lượt0,112,205,279. Pill y6,r16,trắng,stroke0.5 #E3EBE6. Label12/500,line17,#102D28.
Nội dung hiện tại rộng351 nên bốn chip vừa trong viewport353; đã cấu hình scroll ngang nhưng chưa có chip bổ sung ngoài vùng này.

## 3. Map và marker

Viewport `483:1658`:393×768,clip=true,overflow BOTH.
Canvas `483:1659`:500×900 tại(0,0). Base vector `483:1660`:500×900.
Map là **editable schematic**, master mô tả rõ không chính xác địa lý. Không có provider/API key/camera lat-lng/zoom/tile style hoặc tọa độ thật: **Not determined from Figma**.
Palette SVG: #C8E6EA,#C9E5E8,#D7EBD5,#E6E4D7,#E8DDB5,#EEF1E7,#F9FAF5,#FFFFF5.
Vùng map liên tục không bị header và sheet che ở mặc định: y216..648,h432. Map vẫn chạy phía sau các khoảng trống của header; con số432 chỉ tính dải giữa.

Các vị trí dưới đây là trong canvas500×900, không phải GPS:
- VNB Court pin `469:1236`: (96,280),26×30.
- Sky Badminton pin `469:1223`: (255,400),26×30.
- Duy Tân Sport Center pin `469:1249`: (100,548),26×30.
- Cùng pin xanh/viền trắng, shuttle trắng; emblem instance khoảng14.4×14.4 tại(6,3). Dùng SVG gốc đã xuất, không vẽ lại từ phỏng đoán.
- Selected Sky bubble `469:1194`: (207,300),156×52,r18,trắng,bóng S3. HStack padding ngang6,gap8,căn giữa dọc.
  Badge (6,6),40×40,r20,#05644F,shuttle26×26 ở giữa.
  Text block (54,8),96×36,gap3. “Sky Badminton”12/600,line17; “1.3 km · $”11/400,line15; cùng#102D28.
- User location `469:1164`: (152,386),88×88; tâm canvas(196,430).
  Accuracy circle88×88,#2996F5,node opacity15%.
  Dot(34,34),20×20,#1689FA,stroke trắng3,bóng S3.
- Cluster `483:1733`: (168,392),56×56,ẩn mặc định.
  Halo56×56,#05644F,opacity12%; core(8,8),40×40,stroke trắng2,bóng S4. “3”15/600,line21,trắng,tại(23,17).
- Ungrouped pins và cluster được điều khiển visibility bằng prototype Boolean; không có thuật toán cluster theo zoom.

Floating controls: component `481:363`,44×96,dọc,gap8.
Hai nút44×44,r22,trắng,bóng S2; icon20×20,căn giữa,stroke thực tế khoảng1.416667 #05644F.
- Collapsed: cả nhóm màn(333,540); location y540,layers y592.
- Half: nhóm(333,364); location y364,layers y416.
- Expanded: controls ẩn.
Recenter target `483:1739`:canvas(0,46),393×768; chỉ là đích SCROLL_TO của prototype.

## 4. Bottom sheet

Component set `467:394`; cả3 variant có root393×576, instance đặt ở màn(0,192).
Body trắng, chỉ hai góc trên radius26; góc dưới0; bóng S5.
Padding T/R/B/L=8/20/12/20,gap4,Auto Layout dọc.
Grabber touch353×24, handle44×4,r2,#D8DEDA,căn giữa; body-relative y8; handle relative(154.5,10).
Header353×20 tại body(20,36),“Nearby Courts”14/600,line19,#102D28.
- Collapsed hiển thị “3 courts”,11/400,line15,#647976 phía phải.
- Half/Expanded ẩn count và có Collapse44×44,r14,#F0F4F1 tại header(309,-12),icon20×20.
  
| State/master | Body relative host | Body trên màn | Body height | List viewport |
|---|---|---|---:|---|
| Collapsed /467:358 |(0,456)|y648|120|Compact summary353×48 |
| Half-expanded /482:337 |(0,280)|y472|296|353×224 |
| Expanded /467:393 |(0,104)|y296|472|353×400 |

Ở cả3 trạng thái, body kết thúc y768, ngay trước navigation. Mức “Expanded” không chiếm toàn màn.
Dải map giữa header và sheet lần lượt432,256,80px (suy ra từ tọa độ, không phải token).

Compact summary:body(20,60),353×48,master `481:373`.
Photo(0,2),44×44,r12; text block(54,3),215×42,gap3.
Name13/600,line18; metadata gồm star13/500,line18,#F6B42E và “4.6 (128) · 1.3 km”11/400,line15,#647976.
Open now badge(279,14),66×20,r10,#DFF2E8; label10/500,line14,#05644F.
Không có favorite hoặc giá trong summary thu gọn.

Half/Expanded list:body(20,60),gap12,clip=true,scroll dọc.
Ba card353×102 tại list y0,114,228: Sky Badminton,VNB Court,Duy Tân Sport Center.
Master card `466:297` gốc304×102; instance trong sheet rộng353. Không được hiểu width304 của master là width của card đang render.
Card trắng,r14,bóng S6,padding T/R/B/L=4/8/4/4,gap12.
Ảnh body(4,4),92×94,r12.
Summary body(108,4),184×94,paddingTop3,gap5; độ rộng con hiện giữ184 khi instance root tăng353.
Name13/600,line18 tại summary(0,3).
Rating row(0,26),184×16,gap7; star14/500,line19; metadata11/400,line15.
Address(0,47),“Hải Châu, Đà Nẵng”,11/400,line15.
Status row(0,67),184×20,space-between: badge71×20,r10,#DFF2E8,label11/500,line15; “$$”12/500,line17,#05644F.
Heart icon18×18,absolute card(275,9),outline.
Cả3 card hiện dùng cùng ảnh,4.6(128),1.3km,địa chỉ,Open now,$$. Đây là dữ liệu mẫu Figma, không phải dữ liệu sân đã xác thực.
Một số line-height (star19 trong row16) vượt chiều cao row; không sửa bản thiết kế trong lần trích xuất này.

## 5. Panels search/filter/layers

Cả3 là frame con inline trong screen, không phải màn mới hoặc Figma overlay navigation.
Nền trắng,r22,padding16,gap8,bóng S7.
Close button32×32,r16,#F0F4F1,icon20×20. Touch target thực tế32, không tự đổi thành44 khi mô tả Figma.

Search `485:1554`: màn(20,220),353×274.
Header321×32,label “Search courts”16/600,line22.
Query row(16,56),321×44,r14,#F0F4F1,paddingLeft12,gap10; icon18; “Sky Badminton”14/500,line19.
Help(16,108),“Court name or area”,12/400,line17,#647976.
Result(16,133),321×102,tái sử dụng court card.
Query là TEXT mẫu; không có TextField bàn phím thật hoặc tìm kiếm tự do trong Figma.

Filters `485:1582`: màn(20,220),353×352.
Header321×32,“Filters”16/600,line22.
- Distance group(16,56),321×68,dọc gap6; label13/500,line18. Options row y24,321×44,gap8; mỗi option101.6667×44,pill101.6667×36,r20,y4. Text13/500,line18. Default5km; options3/5/10km.
- Availability row(16,132),321×44; label13/500,line18; Open now toggle104×44 tại x217.
- Court type row(16,184),321×44; Indoor toggle104×44 tại x217.
- Price row(16,236),321×44; options group x171,150×44,gap8; hai option71×44,$ và$$.
- Toggle pill36px cao,centered trong44,r20; unselected#F3F6F3,text#142824; selected#05644F,text trắng. Text13/500,line18.
- Apply button(16,288),321×44,r26,#05644F; label “Apply filters”14/600,line20,trắng; gap8 với trailing arrow20×20. Label x106,arrow x195. Master primary `68:16`.
Price toggle độc lập, không có logic exclusive cho$ và$$. Khoảng tiền tương ứng$,$$: **Not determined from Figma**.

Layers `485:1630`: màn(163,360),210×164.
Heading “Map layers”14/600,line19.
Standard row(16,43),178×44; Court clusters row(16,95),178×44; text12/500,line17; check14/600,line19,#05644F tại x166.
Không có satellite/terrain được thiết kế.

## 6. Bottom navigation

Instance `469:1346`,master`194:196`:393×84 tại(0,768),trắng,không viền/bóng được khai báo.
Auto Layout ngang,space-between,padding T/R/B/L=8/12/22/12.
5 item64×48,relative x12,88.25,164.5,240.75,317;y8.
Icon22×22 tại item(21,3.5). Label11/500,line15;gap4,căn giữa.
Home / Map / Match / Feedback / Profile.
Map text/icon#05644F; inactive#7A8985.
Các icon có khác biệt stroke gốc:Home/Feedback1.7,Map1.8,Match1.8 và2,Profile1.8; không giả định tất cả SF Symbols.
Map là selected bằng màu. Profile instance vẫn lấy master Selected nhưng overrides màu xám; ưu tiên hình hiển thị thực tế.
Không export nguyên nav thành ảnh.

## 7. Colors, typography, effects

Tất cả text đọc được dùng **Plus Jakarta Sans**,letterSpacing0%,weight400Regular/500Medium/600SemiBold.
Không có yêu cầu font700 ở frame này.
Primary semantic `color/action/primary`,VariableID57:6 → primitive`green/700`,VariableID55:4 →#05644F.
White primitive`white`,VariableID55:16 →#FFFFFF.
Các mã khác là paint hiện tại, không tự khẳng định là shared design token:
#102D28 primary ink;#647976 muted;#8B9794 placeholder;#7A8985 inactive nav;#DFF2E8 badge;
#F0F4F1 panel-controls;#F3F6F3 unselected choice;#142824 choice text;#E3EBE6 chip stroke;
#D8DEDA drag handle;#F6B42E rating;#1689FA location;#2996F5 accuracy;#FAFBF9 screen.

Shadow tất cả type DROP_SHADOW,offset(0,4),spread0,blend NORMAL,visible=true,colorRGB#133C31:
- S1 segment:blur12,alpha5%.
- S2 search/filter/location/layers:blur12,alpha6%.
- S3 selected bubble/user dot:blur12,alpha8%.
- S4 cluster core:blur12,alpha10%.
- S5 sheet:blur16,alpha6%.
- S6 court card:blur10,alpha5%.
- S7 panels:blur24,alpha12%.
Radius ở đây là blur radius Figma, không tự coi là CSS blur hoặc Flutter sigma tương đương.

## 8. Prototype được xác minh

Initial Boolean: selection=true; search=false; filters=false; layers=false; cluster=false; pins=true; accuracy=true; filtersApplied=false.
Collection “Sprint6 / Court Map Prototype”, Default mode. JSON lưu đầy đủ variable IDs.

| Thao tác | Hành vi được lưu trong Figma |
|---|---|
| Chạm nền Map Markers | selection/search/filters/layers=false |
| Sky pin | selection=true, đóng search/filters/layers; không navigate ngay |
| Sky bubble / VNB pin / Duy Tân pin / collapsed card / search result | Court Preview 469:1028 |
| Find Players | Find Players Map 469:1029 |
| Find Courts trên Players | Trở lại 469:1027 |
| Profile nav | Player Profile 195:178 |
| Home / Map / Match / Feedback nav | Không có reaction điều hướng được xác minh |
| Court Preview Back | BACK |
| Court Preview View Courts | Sprint 4 — 01 Facility Detail + Schedule 301:637 |

Các NAVIGATE trên dùng DISSOLVE, EASE_OUT, 0.25 giây. VNB và Duy Tân cũng dẫn đến cùng preview mẫu; không có preview riêng được xác minh.

Bottom sheet:
- Collapsed grabber click hoặc drag → Half; SMART_ANIMATE, EASE_OUT, 0.30s.
- Half grabber drag → Expanded; 0.25s.
- Expanded grabber drag → Half; 0.25s.
- Half/Expanded collapse button click → Collapsed; 0.25s.
- ON_DRAG không khai báo hướng, threshold hoặc velocity; không khẳng định đây là sheet physics liên tục.
- Card sources trong Half/Expanded không có NAVIGATE ở master đọc được. Instance screen hiện là Collapsed nên navigation override cho card trong variant chưa active: **Not determined from Figma**.
- Không khẳng định đã kiểm thử bằng click toàn bộ prototype; lần này kiểm tra dữ liệu reactions và component.

Current Location:
- Instance Collapsed: accuracy=true, selection/search/filters/layers=false; SCROLL_TO target 483:1739, SCROLL_ANIMATE, EASE_OUT, 0.40s.
- Master Half chỉ có accuracy=true, selection=false. Recenter override của Half tại screen chưa active: **Not determined from Figma**.
- Đây là scroll đến hình mẫu, không phải GPS.

Search/filter/layers:
- Search click mở search, đóng filters/layers. Close panel đóng cả ba.
- Filter button hoặc cả bốn quick chip đều mở cùng Filters panel; đóng search/layers.
- Distance 3/5/10 km là exclusive variants qua CHANGE_TO, Smart Animate 0.25s.
- Open now / Indoor / $ / $$ chuyển Selected=No ↔ Yes, Smart Animate 0.25s.
- $ và $$ là hai toggle độc lập, không có logic exclusive.
- Apply filters: filters=false, filtersApplied=true, selection=false. Dot6×6 hiện. Không thấy reset dot, cập nhật quick chip label hoặc lọc kết quả.
- Layers button mở layers, đóng search/filters.
- Standard: pins=true, cluster=false, layers=false.
- Court clusters: pins=false, cluster=true, selection=false, layers=false.
- Click cluster: cluster=false, pins=true, selection=false, layers=false.
- Heart card: không có favorite action được xác minh.

Không có search API, filter query, quyền GPS, cluster theo zoom, loading/error/empty/offline states hoặc backend contract: **Not determined from Figma**.

## 9. Asset report

Đã xuất **15 SVG** từ node/component gốc bằng Figma MCP, không xuất card/button/tab/text hoặc toàn màn thành ảnh.
Thư mục: `mobile/assets/sprint6/find_courts/`.
Node ID, kích thước gốc, format, path lưu trong `asset_manifest.json`.

| Filename | Figma node | SVG size | Dùng cho |
|---|---|---|---|
| map_base.svg |483:1660|500×900|Map minh họa, không chứa marker/UI |
| court_pin.svg |469:1223|26×30|Pin đã gồm shuttle |
| shuttle_white.svg |I469:1194;466:314|26×26|Badge selected bubble |
| search.svg |I469:1030;467:233|18×18|Search glyph màu muted |
| filter.svg |I469:1030;467:238|20×20|Filter button |
| current_location.svg |I469:1284;482:382;481:349|20×20|Target glyph |
| layers.svg |I469:1284;482:382;481:359|20×20|Layers glyph |
| heart_outline.svg |466:295|18×18|Favorite glyph |
| chevron_down.svg |482:439|20×20|Collapse glyph |
| nav_home.svg |I469:1346;203:176;203:164|22×22|Home |
| nav_map.svg |I469:1346;203:185;203:164|22×22|Map selected |
| nav_match.svg |I469:1346;203:194;203:164|22×22|Match |
| nav_feedback.svg |I469:1346;203:203;203:164|22×22|Feedback |
| nav_profile.svg |I469:1346;203:212;203:170|22×22|Profile inactive |
| button_arrow.svg |65:37|40×40|Arrow master; render20×20 trong Apply |

Ảnh JPEG gốc **444×218**, từ image hash da6375a973a469adb25a6ef671fb8c86cd50a867:
- Node photo: 466:284; compact photo: I469:1284;482:373;481:365.
- **Tái sử dụng `mobile/assets/images/match/facility_court.jpg`**, 10818 bytes.
- SHA-256: e858d7f27839abdb709f999094231b2a867e92f4bb7967371b2607fe6d7ce2d1. Trùng byte với Figma nên không tạo bản ảnh trùng.
- Figma fill CROP; imageTransform [[1,0,0],[0,0.68,0.22]].
- Không tự thay bằng BoxFit.cover rồi gọi là khớp. Cần chuyển crop transform và đối chiếu ảnh render.
- Chưa xác minh bản ảnh độ phân giải cao hơn.

SVG mới được đối chiếu shape attributes với SVG hiện có; không thấy bản trùng shape chính xác. Một số glyph tương tự ở sprint trước có geometry/kích thước/màu khác. Không ghi đè tài sản cũ.

**Không tải được:**
- Close icon20×20 tại 485:1558/485:1586: export trả “no visible layers” vì ancestor panel ẩn. Không bật visibility để xuất vì yêu cầu không sửa Figma.
- Raw vectorPaths của 485:1559 nằm trong prototype_specs.json; path đọc được bất đối xứng. Không tự sửa thành X chuẩn.
- Font binary: không được Figma MCP cung cấp. Project đã dùng GoogleFonts.plusJakartaSans.

Không xuất status bar/home indicator, star hoặc cluster count vì đó là system UI hoặc shape/text, không phải photo asset.

**Pubspec không thay đổi.** Hiện chưa đăng ký assets/sprint6/find_courts/; assets/images/match/ đã đăng ký.
**Khuyến nghị khi triển khai:** thêm directory mới vào pubspec trước khi dùng SVG. Bước này chưa thực hiện.

## === ANTIGRAVITY HANDOFF ===

Bạn đang triển khai **Sprint 6 — Find Courts Map** trong S-Match Flutter.
Không có Figma MCP ở máy bạn: dùng toàn bộ thông số mục1–9 ngay trong tài liệu này và JSON cùng thư mục. Không cần truy cập Figma lại.

### Đầu vào và phạm vi

Nguồn đã xác minh: file XSwsBDmz46CduUchU8k2KZ, node469:1027, ngày2026-10-14.
Frame393×852; giữ bản map-first hiện tại, không khôi phục Explore title đã ẩn hoặc dùng concept cũ.
Không rasterize card, button, nav, text, badge, cluster hoặc toàn screen.

Các file đầu vào nằm ở `mobile/assets/sprint6/find_courts/`:
- FIND_COURTS_HANDOFF_VI.md: tài liệu đầy đủ này.
- figma_specs.json: parent IDs, geometry, fill/font/layout của header/map/nav/sheet/panels và component gốc.
- prototype_specs.json: variant reactions, nội dung panel ẩn, close vectorPaths, đích navigation và asset metadata.
- asset_manifest.json: filename/path/node ID/format/dimensions.
- 15 SVG theo bảng mục9.
- Photo dùng lại ở `mobile/assets/images/match/facility_court.jpg`.

### Bố cục bắt buộc

- Screen393×852, nền#FAFBF9.
- Map viewport393×768 tại(0,0), clip, pan hai chiều; canvas500×900.
- Floating header216 cao: status52 + controls164. Horizontal margin20, gap8.
- Segment(20,60),353×44; Search(20,112),301×44; Filter(329,112),44×44.
- Chips viewport(20,164),353×44; pill32 cao, gap8.
- Map vector/pins/location/bubble tọa độ chính xác trong mục3.
- Sheet host(0,192),393×576. Body top trên màn648/472/296, height120/296/472; bottom luôn768. Top corners26.
- Compact353×48; expanded list cards353×102,gap12. Không lấy width304 của master làm width sheet card.
- Navigation(0,768),393×84; Home/Map/Match/Feedback/Profile; Map selected.
- Conditional Search(20,220),353×274; Filters(20,220),353×352; Layers(163,360),210×164.
- Mục2–6 có đầy đủ padding, offset, child sizes và nội dung text. JSON xy của node con là **relative parent**, không phải screen coordinates.

### Style bắt buộc

Plus Jakarta Sans Regular400/Medium500/SemiBold600, letterSpacing0%.
Giữ nguyên fontSize/lineHeight theo từng component trong mục2–7.
Primary#05644F, white#FFFFFF; text#102D28, muted#647976, placeholder#8B9794, inactive#7A8985.
Badge#DFF2E8; chip border#E3EBE6,0.5; panel control#F0F4F1; unselected choice#F3F6F3.
Radius và bảy loại shadow được ghi chính xác ở mục7; không tăng blur/gradient/shadow.
Chỉ primary/white được xác minh là token binding; không tự coi mọi paint là semantic token.

### State và tương tác bắt buộc

Default: sheetCollapsed; selectedSky bubble hiện; pins hiện; accuracy hiện; panels/cluster/applied dot ẩn.
Ba sheet state và transition timings theo mục8.
Search là query/result mẫu; filter chỉ chuyển toggle/distance/visibility; clustering là nhóm mẫu3, không có algorithm.
Các route đã xác minh:
- Find Players ↔ Find Courts.
- Selected bubble / VNB pin / Duy Tân pin / compact card / search result → Court Preview469:1028.
- Profile → Player Profile195:178.
- Court Preview View Courts → Sprint4 Facility Detail + Schedule301:637.
- Court Preview Back → previous.
Home/Match/Feedback, favorite, card navigation overrides trong Half/Expanded và recenter override Half: **Not determined from Figma**. Không tự khẳng định hoạt động.

### Tái sử dụng

Figma components:
Header467:249; Status466:210; Sheet set467:394; Compact481:373;
Court card466:297; Controls481:363; Selected bubble466:326; User location466:336;
Nav194:196; Toggle set484:399; Distance set484:435; Primary68:16.

Project đã xác minh:
- `mobile/lib/core/theme/app_colors.dart`: AppColors.primary=#05644F và white.
- `mobile/lib/core/theme/app_text_styles.dart`: sử dụng GoogleFonts.plusJakartaSans.
- Photo JPEG có sẵn và đã đăng ký assets/images/match/.
Không đồng nhất AppColors.background=#F7F8F5 với frame hiện tại#FAFBF9.
Chưa xác minh có Flutter widget map/sheet phù hợp; không tự tuyên bố có sẵn.

### Khuyến nghị triển khai — KHÔNG phải dữ liệu Figma

- Có thể dùng Stack với widget riêng cho search/filter/marker/bubble/controls/summary/card/sheet/nav.
- Có thể dùng DraggableScrollableSheet hoặc sheet controller để tái hiện ba đỉnh y648/472/296. Các phần trăm responsive phải suy ra từ vùng layout thực tế, không dùng tỷ lệ tùy ý.
- Dùng safe area của thiết bị thật; không hardcode status bar/Dynamic Island giả trên production.
- Với demo offline, dùng map_base.svg và tọa độ canvas đã ghi.
- Với map production, phải chốt provider, camera, location permission, dữ liệu sân và phép chiếu marker riêng.
- Search/filter thật, tự động cluster và favorite cần logic/data riêng. Không biến mock prototype thành lời khẳng định backend đã có.
- Cần đăng ký asset directory trong pubspec khi bắt đầu implementation; lần bàn giao này chưa sửa pubspec.
- Render đúng crop ảnh và font; kiểm tra tại393×852.

### Thông tin chưa xác định

Safe-area iOS thực; map provider/API key/GPS/zoom/lat-lng; query/API/schema; loading/error/empty/offline/favorite;
route Home/Match/Feedback; khoảng tiền $/$$; card navigation override Half/Expanded; recenter Half; close SVG export;
font binary: **Not determined from Figma** hoặc giới hạn export đã mô tả ở mục9.

