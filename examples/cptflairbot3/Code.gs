function doGet(e) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const range = sheet.getRange("A2:D100");          // hardcode
  console.log(e.parameter.payload);
  payload = JSON.parse(Utilities.newBlob(Utilities.base64Decode(e.parameter.payload)).getDataAsString());
  range.moveTo(range.offset(1, 0));
  sheet.getRange("A2:2").setValues( [ [
    payload.messaged_at,
    payload.processed_at,
    payload.name,
    payload.text,
  ] ] );                                            // hardcoded columns order
}
