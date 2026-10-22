# CSA Stair Drawing — giao diện và mặt cắt từ Excel

## Bản chạy một file

Tải `CSA_StairDrawing.lsp` tại thư mục này. File đã gộp toàn bộ helper cần thiết, không cần tải Lisp/DCL khác hoặc import VBA. Đây là giao diện DCL chạy trong AutoCAD Windows, chưa phải file `.dvb` hoặc UserForm đã đóng gói.

1. Mở **bản sao** `CSA Drawing Data.Rev12.dwg` (file mẫu ở nhánh `main`), vào tab Model. Đơn vị `INSUNITS=4` (mm).
2. Mở `CSA_Stair Drawing Tools.xlsm` trong Excel, kiểm tra sheet `Cau Thang Tools` đã tính ra tọa độ. Chờ Excel tính xong.
3. `APPLOAD` file **`CSA_StairDrawing.lsp`**.
4. Gõ **`CSA_STAIR_DRAWING`**.
5. Bấm **Load / Reload Excel**, chọn đúng file `.xlsm` đang mở. Trạng thái báo số dòng và số đỉnh sau khi loại các điểm trùng liên tiếp.
6. Chọn DimStyle **GB 25**, kiểm tra tên cầu thang, mã mặt cắt và hai cao độ. Với dữ liệu trong repository: cao độ dưới **+0.050 m**, trên **+2.250 m**. Bật **Concrete details** và **Step counts from Excel**; thử **Title height = 200 mm**, **Dimension spacing = 400 mm**.
7. Bấm **Preview**, chọn điểm chèn trong vùng trống. Hộp thoại đóng để bạn có thể zoom/pan kiểm tra hình thật.
8. Gõ lại **`CSA_STAIR_DRAWING`** để mở giao diện với dữ liệu đã nạp. Bấm **Draw Section**, chọn điểm chèn bản vẽ chính thức.
9. Preview được xóa sau khi xuất thành công. Để chỉ xóa preview, mở lại giao diện và bấm **Clear Preview**.

Sau khi thay đổi Excel phải bấm **Load / Reload Excel**; không có đồng bộ nền. Nút Close chỉ đóng giao diện, không tự xóa preview để người dùng kiểm tra ngoài viewport. Khi đổi DWG, dữ liệu Excel đã nạp vẫn có thể dùng, nhưng tài nguyên và đơn vị của DWG đích được kiểm tra lại trước mỗi lần vẽ.

## Scale đã chốt từ hình người dùng

| Block | Scale X/Y/Z |
|---|---:|
| `Cao do` | **0.25** |
| `Daucat` | **0.01** |
| `So hieu thep` | **0.35** |
| `CSA_Sohieu-KCthep` | **1.0**, giữ nguyên như mẫu không có ghi chú đổi scale |

Các mặc định này áp dụng cho template và mẫu GB 25 đã chốt; không tự nhân theo mẫu số tỷ lệ của DimStyle khác. `CSA_STAIR_TEST` trong cùng file cũng dùng các scale cố định này để có thể kiểm tra lại bộ ký hiệu.

### Sửa lỗi scale trong bản concrete-details v2

Ảnh người dùng cho thấy `Daucat` khai báo Inches, Unit factor 25.4 và scale tham chiếu khoảng 0.0003, dù giá trị truyền cho InsertBlock là 0.0075. Bản mới đọc lại `XScaleFactor` sau khi chèn, dùng `ScaleEntity` để đưa scale tham chiếu về đúng mức đã chốt và kiểm tra cả ba trục. Phép biến đổi đi cùng các attribute; không đổi `INSUNITS`, định nghĩa block hoặc các block cũ.

Khi kiểm tra lại, **Properties của block Daucat mới phải có Scale X/Y/Z = 0.01**, vẫn có thể giữ Block Unit = Inches và Unit factor = 25.4. Nếu khác, gửi ảnh Properties mới; phần COM này cần xác nhận trong AutoCAD, không thể chứng minh bằng kiểm tra trên Linux.

## Giao diện hiện thực hiện được

- Chọn Excel bằng hộp thoại file, không phải gõ đường dẫn.
- Chọn DimStyle từ danh sách của DWG đích.
- Tên cầu thang, mã mặt cắt, cao độ, chiều cao tên và khoảng cách các hàng dim có thể chỉnh trên giao diện.
- Đọc đường bao bê tông từ Excel; loại điểm liên tiếp trùng nhau và điểm đóng cuối trùng đầu.
- Preview bằng polyline kín, kèm tùy chọn kích thước tổng thể, **dimension cấu tạo bê tông**, cao độ và ký hiệu mặt cắt.
- Tên cầu thang căn giữa dưới đường bao, tách khỏi chiều cao chữ DimStyle; bên dưới là cụm **MAT CAT + block Daucat**. Các thành phần được căn theo bounding box sau khi block đã được hiệu chỉnh scale.
- Xuất cùng đường bao sang `21-GB-BD`; kích thước sang `04-GB-Dim`; chữ sang `10-GB-Text`; cao độ sang `11-GB-Cao Do`; ký hiệu sang `12-GB-Ky Hieu`.
- Các đối tượng gốc của preview nằm trên `CSA-PREVIEW` và được đánh dấu riêng. Block vẫn giữ layer/thuộc tính của các entity nội bộ theo định nghĩa CSA.
- Chỉ tạo `CSA-PREVIEW` nếu thiếu, đặt non-plot cho layer vừa tạo. Giữ nguyên các layer, block và style có sẵn.
- Mỗi lần xuất chính thức tạo một nhóm hình mới tại điểm chèn, không tự sửa hoặc xóa bản vẽ chính thức cũ. Dùng UNDO nếu cần hoàn tác lần xuất.

## Hợp đồng dữ liệu bê tông đang dùng

Nguồn duy nhất ở vòng này là sheet **`Cau Thang Tools`**. Không tự nối dữ liệu khác nghĩa trong `3-SIDES`.

| Vùng | Ý nghĩa |
|---|---|
| `BY2:BY500` | STT, dừng khi gặp ô trống |
| `BZ2:BZ500`, `CA2:CA500` | Tọa độ X/Y theo mm |
| `D22` | Chênh cao sàn, mm |
| `M30` | Cao độ sàn dưới, m |
| `AD33` | Tên cầu thang |
| `H19`, `Z19`, `BA19` | Chiều dài chiếu nghỉ dưới, hình chiếu vế xiên, chiếu tới |
| `D31`, `D33` | Chiều dày bản dưới và phần dầm nhô dưới bản |
| `BU21`, `BU22` | Chiều dày bản trên và phần dầm nhô dưới bản |
| `AO27` | Chiều dày bản xiên đo vuông góc |

Trong workbook hiện tại, tọa độ đầu là mốc sàn dưới; điểm có Y lớn nhất là mốc sàn trên. Chênh cao phải khớp `D22`. Nếu file khác thay đổi ý nghĩa này, tiện ích báo lỗi thay vì tự đoán. Khi nhập cao độ trên giao diện, chênh lệch cũng phải khớp hình học trong sai số 0.5 mm.

**Overall width** chỉ vẽ tổng ngang 6500 theo hình người dùng. Đã bỏ 5 dim đánh X: tổng cao dầm dưới 400, tổng cao dầm trên 400, lọt lòng dưới 1700, lọt lòng trên 1100 và tổng cao bao 2600. Hình học bê tông không thay đổi; vẫn giữ chênh cao sàn 2200, các dim 120/280 và bề rộng các gối.

### Dimension cấu tạo bê tông

Bản hiện tại giữ riêng 24 điểm gốc theo STT trước khi loại trùng để nhận diện các chi tiết trong mẫu Excel. Với dữ liệu gốc, bật Concrete details sẽ tạo 15 dimension:

| Nhóm | Kích thước mẫu (mm) |
|---|---|
| Chuỗi ngang phía trên | 2000 / 3000 / 1500 |
| Chênh cao sàn | 2200 |
| Bản dưới / dầm nhô dưới bản | 120 / 280 |
| Bề rộng gối dưới | 200 và 250; không còn dim 1700 |
| Bản trên / dầm nhô dưới bản | 120 / 280 |
| Bề rộng gối trên | 200 và 200; không còn dim 1100 |
| Chênh cao đầu/cuối đoạn xiên | 314.286 / 157.143, hiển thị theo độ chính xác DimStyle |
| Bản xiên | 120, **đo vuông góc** giữa hai biên |

Các số là số đo hình học, không ghi đè text dimension. Dimension ngang/đứng dùng `AddDimRotated`; chiều dày bản xiên dùng `AddDimAligned` sau khi chiếu vuông góc. Đoạn có kích thước bằng 0 được bỏ qua, không tạo dim rỗng. Khi thông số Excel không khớp đường bao trong sai số 0.5 mm, hoặc hai biên xiên không song song, chương trình báo lỗi trước khi dựng hình mới. Tắt Concrete details nếu chỉ cần đường bao từ một workbook khác không theo hợp đồng 24 điểm này.

Các dim 314/157 là chênh cao hình học ở hai đầu bản xiên. Số bậc được ghi riêng từ U28/AI23; bản này chưa dựng đường răng cưa từng bậc trên biên bê tông.

Excel được **kết nối vào phiên đang chạy**. Tiện ích không tạo/đóng Excel, không ghi ô, không tự bật macro hay tính lại workbook. Nếu có nhiều phiên Excel, hãy mở workbook trong phiên mà AutoCAD kết nối được; thông báo sẽ chỉ rõ nếu không tìm thấy file đang mở. Ô Excel lỗi, dữ liệu không hợp lệ hoặc đường bao suy biến sẽ bị từ chối trước khi thay dữ liệu đã nạp.

## Kiểm tra nghiệm thu vòng này

Gửi ảnh gồm giao diện sau Load Excel và mặt cắt sau Preview/Draw Section. Kiểm tra:

1. Đường bao khớp hình trong workbook, giữ đúng gối/dầm và chiều dày.
2. Cao độ hiển thị ba số lẻ, đúng vị trí và scale 0.25.
3. Tên cầu thang và cụm MAT CAT căn giữa dưới hình, đủ lớn với Title height 200. Ký hiệu mặt cắt có scale tham chiếu 0.01; kích thước dùng GB 25.
4. Có các chuỗi kích thước cấu tạo như bảng trên; bản xiên đo được 120, không phải khoảng cách đứng giữa hai biên.
5. Preview lặp lại không chồng hình; Clear Preview giữ nguyên hình chính thức và các đối tượng khác trên cùng layer.
6. Khi Excel đang có lỗi hoặc tài nguyên CSA thiếu/khóa, có thông báo và không xuất hình dở dang mới.

Nút **Plan (next phase)** được vô hiệu hóa: bảng tọa độ đang có là đường bao mặt cắt, chưa chứa dữ liệu mặt bằng 2 vế/3 vế. Đã có tùy chọn tim thép dọc và thép chiếu nghỉ ở giai đoạn kiểm tra, chưa có thống kê hoặc móc/uốn hoàn chỉnh. Không lấy các thanh mẫu ở tiện ích kiểm tra để thay cho thiết kế. Bản này chưa triển khai toàn bộ cầu thang 2/3 vế.

## Bản rebar-detail v4.3: sửa lỗi ghi chân dim

Ảnh lỗi `Cannot set fixed extension length on dimension` cho biết lời gọi `entmod` của v4.2 trả về nil khi ghi override DSTYLE; code sau đó gọi `exit` nên dòng tiếp theo là `quit / exit abort`. Đây là lỗi tại bước ghi thuộc tính dimension.

V4.3 bỏ phần tự ghi DSTYLE xdata và dùng lệnh **DIMOVERRIDE** của AutoCAD để đặt `DIMFXLON=On`, `DIMFXL=150 / effective DIMSCALE`. Chỉ các dimension vừa tạo được gom theo scale vào selection set; mỗi nhóm chạy một lệnh, không chọn dim cũ hoặc đổi định nghĩa DimStyle. Với 16 dim cùng GB 25, chỉ gọi một lần với DIMFXL=6. `command-s` chạy đầy đủ tham số, không chờ người dùng nhập trong quá trình vẽ. CMDECHO được khôi phục cả khi lệnh báo lỗi.

Sau APPLOAD cần thấy **rebar-detail v4.3**, rồi Load / Reload Excel và Preview ở vùng trống. Kiểm tra chân dim 150 mm và các số đo như trước. Bản sửa đã kiểm tra cách gom selection, bù scale, tham số lệnh và xử lý lỗi bằng stub offline; vẫn cần xác nhận lệnh chạy trong AutoCAD thực tế. Kiểm tra số bậc của v4.2 được giữ nguyên, nên cấu hình đầu bản xiên 0 mm vẫn cần tắt Step counts from Excel để kiểm tra riêng đường bao/thép như đã hướng dẫn.

## Bản rebar-detail v4.2: chân dim và bố trí ghi chú

Bản này sửa ba điểm theo ảnh phản hồi mới:

1. **Chân dim cố định 150 mm trong Model.** Mỗi dimension mới có override `DIMFXLON=1`, `DIMFXL=150 / DIMSCALE`. Với GB 25 có scale 25 thì giá trị lưu DIMFXL là 6, khi vẽ được 150 mm. Đây là phần chân dưới đường dim; độ nhô qua đường dim vẫn theo CSA DimStyle. Chữ/số đo và các định nghĩa DimStyle có sẵn được giữ nguyên. Các hàng dim vẫn cách hình theo Dimension spacing.
2. **Quy ước tim theo hình 2:** biên bê tông tới tim thép dọc = `BJ28`; tim chấm vào trong thêm `d cấu tạo / 2`. Không cộng thêm d thép dọc vào khoảng cách này. Ví dụ cover 25/d12: tim dọc ở 25 mm, tim chấm ở 31 mm. Hai đường tim song song với biên xiên và áp dụng tương tự cho bản chiếu nghỉ. Đây là quy ước thể hiện tim được người dùng yêu cầu, thay quy ước cover tới mặt ngoài thanh ở v4.1.
3. **Leader thẳng, đoạn ngang dưới text.** V4.1 dùng nhầm `AcLeaderType=1` (spline); v4.2 dùng `0` (acLineWithArrow), đặt lại Type và ba đỉnh sau khi gán annotation/style. Nhánh ngang lấy vị trí dưới bounding box thực tế của attribute DK-KC, chạy qua bề rộng text, thay vì đi qua tâm cả block.

UI thêm **Dot blank size (mm)** = 60 và **Tick size (mm)** = 100. Đây là kích thước đầu leader trong Model, không phải scale block hoặc đường kính thép chấm. Có thể chỉnh trên UI để kiểm tra trực tiếp; các giá trị phải dương. Chấm thép vẫn có đường kính thật theo BJ36.

### Lỗi ActiveX đã sửa ở v4.1

V4 gọi `AddLeader` với Annotation = `nil`. Tham số này nhận đối tượng COM; `nil` có thể bị chuyển thành tham số thiếu, dẫn tới `ActiveX Server returned an error: Parameter not optional`. V4.1 truyền **BlockReference ghi chú CSA vừa chèn** làm Annotation. Hai loại đầu leader vẫn được đặt trên từng entity.

Thông báo lỗi mới nêu rõ bước đang chạy, ví dụ `Leader: AddLeader with CSA block annotation` hoặc `Leader: set ArrowheadType`, kèm nguyên văn lỗi ActiveX trong hộp thoại và F2. Các đối tượng vừa tạo được dọn khi lỗi; preview cũ chỉ được thay sau khi dựng hình mới thành công. Bản sửa đã kiểm tra hợp đồng truyền tham số bằng stub offline, chưa được thực thi COM trong AutoCAD tại môi trường này.

### Leader, số bậc, neo và thép chấm

Sau APPLOAD bản mới, **Load / Reload Excel** để đọc đủ thông số, bật **Step counts from Excel** và **Rebar draft**, rồi Preview tại vùng trống. Tùy chọn Rebar draft mặc định tắt. Bản v4 đã có các thay đổi theo ảnh phản hồi:

- Ghi chú thanh trong mặt cắt dùng entity **LEADER**, đầu **Architectural tick**. Ghi chú thép chấm dùng **Dot blank**. Cả hai có đoạn ngang nối tới mép block ghi chú, lấy mép sau khi đã cập nhật bounding box. Arrowhead được đặt trực tiếp trên leader, không đổi DimStyle hiện có hoặc biến hệ thống DIM.
- Số bậc lấy từ **AI23 = 12 bậc vế xiên**, **U28 = 2 bậc đầu** trong file mẫu. Nhãn hiển thị `12 BAC`, `2 BAC` để tương thích môi trường AutoLISP/font cũ. Không suy số bậc từ độ dài đoạn xiên hoặc tự tạo thêm đường bao bậc. Chiều cao một bậc AV21 được kiểm tra với tổng chênh cao và hai đầu đoạn xiên.
- Thép chiếu nghỉ/chiếu tới bẻ theo lớp tương ứng, qua đoạn bê tông giật cấp rồi **kéo vào vế xiên 30d**. Người dùng đã xác nhận giữ 30d và theo biên bê tông hiện có; hình 3 chỉ là tham khảo hướng neo, không lấy kích thước từ ảnh. Chiều dài này được đo dọc đoạn xiên, không cộng đoạn đứng chuyển tiếp.
- Thép cấu tạo BJ36 được vẽ thành **chấm tròn đặc**, thể hiện thanh vuông góc mặt cắt. Chấm có đường kính thật của thanh. Khoảng cách tim chấm đo dọc bản xiên hoặc bản chiếu nghỉ, lưới được căn giữa với hai đầu dư bằng nhau và giữ nguyên bước thép.

### Nguồn thông số

| Ô | Dữ liệu sử dụng |
|---|---|
| `BJ28` | Khoảng cách biên tới tim thép dọc theo hình 2; không cộng d thép dọc/2 |
| `BJ29`, `BJ31` | Bề rộng vế/chiếu nghỉ, chưa dùng để suy số thanh toàn bộ mặt bằng |
| `BJ32`, `BJ33` | Thép chiếu nghỉ dưới/trên, thanh nằm trong mặt cắt và neo vào vế xiên |
| `BJ34`, `BJ35` | Thép dọc dưới/trên, dạng `12a150` |
| `BJ36` | Đường kính/bước thép cấu tạo vuông góc mặt cắt, dạng `12a100` |
| `BJ37` | 1 hoặc 2 lớp, áp dụng cho vế xiên và chiếu nghỉ; 1 lớp chỉ dựng lớp dưới |
| `BJ38` | Hệ số neo theo d; dùng cho đoạn ngang của thép vế xiên và đoạn xiên của thép chiếu nghỉ |
| `BJ39` | Số hiệu thanh bắt đầu, tăng liên tục cho các nhóm đang bật |
| `BJ40`, `BJ41` | Số cấu kiện và kiểu triển khai, đọc để mở rộng; chưa lập thống kê |
| `U28`, `AI23`, `AV21` | Số bậc đầu, số bậc vế xiên, chiều cao một bậc |
| `Z23`, `Z24` | Yes/No: vẽ thép mặt cắt chiếu nghỉ trên/dưới |
| `Z25`, `Z26` | Yes/No: vẽ chấm thép cấu tạo chiếu nghỉ trên/dưới |

Bật/tắt thanh chiếu nghỉ và bật/tắt chấm chiếu nghỉ là hai lựa chọn độc lập theo Excel. Thép cấu tạo trong vế xiên luôn đi cùng Rebar draft. BJ36 được dùng chung cho ba vùng vì workbook hiện chỉ có một đầu vào thép cấu tạo. Số lớp lấy từ BJ37.

Chấm thép được đặt **vào phía trong đường tim thép dọc**: khoảng cách tim chấm tới biên bằng BJ28 + nửa đường kính thép cấu tạo BJ36. Đường kính thép dọc không làm thay đổi khoảng cách tim này. Chấm được tạo bằng polyline hai cung có bề rộng, không tạo hatch/block cho từng chấm và không đổi PDMODE. Nếu DWG tắt FILLMODE, phần tô của wide polyline có thể không hiển thị đầy đủ; đây là thiết lập hiển thị của bản vẽ.

### Phạm vi hình học thép

Thép vế xiên vẫn là một tim thanh đại diện mỗi lớp, có đoạn ngang neo vào hai chiếu nghỉ dài đúng BJ38 × đường kính. Thép chiếu nghỉ có đoạn ngang tới gần biên, đoạn chuyển tiếp qua phần bê tông giật cấp, rồi đoạn xiên neo vào vế thang cũng dài BJ38 × đường kính. Với d12/30d, mỗi đoạn neo tương ứng dài **360 mm**.

Tim thanh được nối bằng các đoạn thẳng để kiểm tra bố trí, chưa thêm bán kính uốn hoặc suy ra chiều dài cắt gia công. Các đoạn thép vế xiên và chiếu nghỉ có thể trùng hình chiếu; vị trí theo chiều rộng, nối chồng và khoảng cách thanh tại nút chưa được giải quyết bằng bản vẽ 2D này. Ghi chú `REBAR DRAFT` đi cùng hình.

Chương trình kiểm tra đường thanh/chấm nằm trong bê tông, đủ cover và hai lớp cùng loại không đè lên nhau. Nếu neo không đủ chỗ, báo lỗi và giữ preview trước, không tự rút ngắn thanh. Nếu hai lớp chấm thép không đủ chỗ theo chiều dày bản, cần sửa thông số; không tự giảm đường kính, bỏ lớp hoặc đổi cover. Giới hạn 2000 chấm cho mỗi vùng/lớp tránh đầu vào bước thép quá nhỏ làm treo AutoCAD. Các kiểm tra này chưa tính khoảng cách tối thiểu theo tiêu chuẩn thiết kế.

Thép dùng `18-GB-Reinf`, leader/ghi chú dùng `20-GB-GC`. Block `CSA_Sohieu-KCthep` giữ scale 1.0 với tag `SH`, `DK-KC`; text đường kính dùng mã `%%C`. Preview dùng hệ đánh dấu riêng và layer `CSA-PREVIEW` như trước.

### Kiểm tra trong AutoCAD

1. APPLOAD file mới, command line phải báo **rebar-detail v4.3**. Load / Reload Excel một lần.
2. Bật Step counts from Excel và Rebar draft, Preview ở vùng trống. File mẫu có `12 BAC` và `2 BAC`.
3. Chọn leader trong Properties: Type là Straight/Line with arrow; thanh mặt cắt dùng Architectural tick size 100, chấm thép dùng Dot blank size 60 (hoặc giá trị vừa nhập trên UI). Nhánh ngang phải nằm dưới text DK-KC, không còn đường spline.
4. Kiểm tra chấm theo BJ36: mặc định d12, bước tim 100 mm; đo dọc bản xiên. Với BJ28=25, tim dọc cách biên 25 và tim chấm cách biên 31 mm. Kiểm tra cả hai lớp và từng chiếu nghỉ đang bật. Đo chân dim được 150 mm ở các hàng dim, kể cả tổng ngang, tổng chênh cao và dim bản xiên.
5. Zoom vào hai nút: thanh chiếu nghỉ phải đi tiếp vào vế xiên, không kết thúc ngang cụt như v3. Đo đoạn xiên neo d12/30d được 360 mm; đoạn đứng chuyển tiếp không tính vào 360 này.
6. Thử đổi Yes/No Z23:Z26 trong Excel, Load / Reload rồi Preview; số hiệu chỉ gán cho nhóm được vẽ. Đổi cover theo workbook, không khóa cứng 15/25.
7. Draw Section tại điểm mới khi đã kiểm tra. Các bản vẽ chính thức cũ không tự cập nhật.

## Kiểm tra mã nguồn

Đã kiểm tra tên layer/tag với CSV gốc và thực thi các helper xử lý tọa độ/định dạng bằng evaluator giới hạn cho hàm thuần. Bộ kiểm tra dùng chính 24 dòng tọa độ được lưu trong workbook. Chưa thực thi COM Excel, DCL hoặc dựng entity trong AutoCAD từ môi trường Linux.

Nguồn UI ở `../ui/CSA_StairDrawing.core.lsp`, planner dimension ở `../ui/CSA_StairConcreteDetails.lsp`, tim thép ở `../ui/CSA_StairRebar.lsp`; bản một file được tạo bằng `python3 stair-tool/tools/build_stair_bundle.py`. Không sửa trực tiếp file gộp. Chạy `python3 -m unittest discover -s stair-tool/tests -v` để kiểm tra.

Khi nạp đè bản cũ, cần bấm **Load / Reload Excel một lần** để có thêm thông số cấu tạo. Các bản vẽ chính thức cũ không tự cập nhật; chọn một điểm mới để so sánh. Tên phiên bản xuất ở command line là **rebar-detail v4.3**.
