export class FaceStore {
  private static map: Map<number, string> = new Map();

  static init(): void {
    // QQ emoji IDs → Unicode (covering the most common ones)
    let pairs: [number, string][] = [
      [0, '\uD83D\uDE04'], [1, '\uD83D\uDE04'], [2, '\uD83D\uDE02'],
      [3, '\uD83D\uDE18'], [4, '\uD83D\uDE0A'], [5, '\uD83D\uDE2D'],
      [6, '\uD83D\uDE1E'], [7, '\uD83D\uDE33'], [8, '\uD83D\uDE21'],
      [9, '\uD83D\uDE0E'], [10, '\uD83D\uDE0D'], [11, '\uD83D\uDE23'],
      [12, '\uD83D\uDE31'], [13, '\uD83D\uDE36'], [14, '\uD83D\uDE0F'],
      [15, '\uD83D\uDE44'], [16, '\uD83D\uDE24'], [17, '\uD83E\uDD23'],
      [18, '\uD83D\uDE16'], [19, '\uD83D\uDE12'], [20, '\uD83D\uDE11'],
      [21, '\uD83D\uDE10'], [22, '\uD83D\uDE37'], [23, '\uD83D\uDE30'],
      [24, '\uD83D\uDE34'], [25, '\uD83D\uDE1D'], [26, '\uD83D\uDE35'],
      [27, '\uD83D\uDE0C'], [28, '\uD83D\uDE28'], [29, '\uD83D\uDE07'],
      [30, '\uD83D\uDE27'], [31, '\uD83D\uDE08'], [32, '\uD83D\uDE22'],
      [33, '\uD83D\uDE06'], [34, '\uD83D\uDE1C'], [35, '\uD83D\uDE05'],
      [36, '\uD83D\uDE29'], [37, '\uD83D\uDE1B'], [38, '\uD83D\uDE01'],
      [39, '\uD83D\uDE00'], [40, '\uD83D\uDE17'], [41, '\uD83D\uDE13'],
      [42, '\uD83D\uDE2B'], [43, '\uD83D\uDE32'], [44, '\uD83E\uDD2F'],
      [45, '\uD83E\uDD14'], [46, '\uD83D\uDE09'], [50, '\uD83D\uDE4F'],
      [51, '\uD83D\uDCAA'], [53, '\uD83C\uDF38'], [54, '\uD83C\uDF39'],
      [55, '\uD83C\uDF3A'], [56, '\uD83C\uDF37'], [57, '\uD83D\uDC90'],
      [58, '\uD83C\uDF3B'], [59, '\uD83C\uDF3C'], [60, '\u2615'],
      [61, '\uD83C\uDF3F'], [63, '\uD83D\uDC7F'], [64, '\uD83D\uDC7B'],
      [65, '\uD83D\uDC7D'], [66, '\uD83D\uDC7C'], [67, '\uD83D\uDC7E'],
      [72, '\u26BD'], [73, '\uD83C\uDFBE'], [74, '\uD83C\uDFC0'],
      [75, '\uD83C\uDFC8'], [76, '\u267B'], [78, '\uD83E\uDD4A'],
      [79, '\uD83C\uDF56'], [82, '\u2764'], [83, '\uD83D\uDC94'],
      [84, '\uD83D\uDC4D'], [85, '\uD83D\uDC4E'], [86, '\uD83D\uDC4C'],
      [87, '\uD83D\uDC4B'], [88, '\uD83D\uDC46'], [89, '\uD83D\uDC47'],
      [90, '\uD83D\uDC48'], [91, '\uD83D\uDC49'], [92, '\uD83D\uDC4F'],
      [93, '\uD83D\uDC4E'], [96, '\uD83C\uDF1E'], [97, '\u2601'],
      [98, '\u2614'], [99, '\u2600'], [100, '\u2744'],
      [101, '\uD83C\uDF08'], [102, '\uD83C\uDF19'], [103, '\uD83D\uDC7A'],
      [104, '\uD83D\uDCB0'], [105, '\uD83C\uDF92'], [106, '\uD83C\uDF49'],
      [107, '\uD83C\uDF4E'], [108, '\uD83C\uDF4C'], [109, '\uD83C\uDF4B'],
      [110, '\uD83C\uDF4D'], [111, '\uD83C\uDF53'], [112, '\uD83C\uDF47'],
      [113, '\uD83C\uDF51'], [114, '\uD83C\uDF34'], [115, '\uD83C\uDF35'],
      [116, '\uD83D\uDCA9'], [120, '\uD83C\uDF64'], [121, '\uD83C\uDF55'],
      [122, '\uD83C\uDF5D'], [123, '\uD83C\uDF63'], [124, '\uD83C\uDF5B'],
      [125, '\uD83C\uDF66'], [126, '\uD83C\uDF5A'], [127, '\uD83C\uDF60'],
      [128, '\uD83C\uDF6E'], [129, '\uD83C\uDF5E'], [130, '\uD83D\uDC15'],
      [131, '\uD83D\uDC08'], [132, '\uD83D\uDC0D'], [133, '\uD83D\uDC14'],
      [134, '\uD83D\uDC31'], [135, '\uD83D\uDC12'], [136, '\uD83D\uDC30'],
      [137, '\uD83D\uDC39'], [138, '\uD83D\uDC3B'], [139, '\uD83D\uDC33'],
      [140, '\uD83D\uDC3A'], [141, '\uD83D\uDC28'], [142, '\uD83D\uDC0C'],
      [143, '\uD83D\uDC0F'], [144, '\uD83D\uDC29'], [145, '\uD83D\uDC32'],
      [146, '\uD83D\uDC1F'], [147, '\uD83D\uDC22'], [148, '\uD83D\uDC0E'],
      [149, '\uD83D\uDC34'], [150, '\uD83D\uDC0B'], [151, '\uD83D\uDC36'],
      [152, '\uD83D\uDC13'], [153, '\uD83D\uDC23'], [154, '\uD83D\uDC24'],
      [155, '\uD83D\uDC27'], [156, '\uD83D\uDC26'], [158, '\uD83D\uDC19'],
      [159, '\uD83D\uDC1D'], [160, '\uD83D\uDC20'], [164, '\uD83C\uDFC1'],
      [165, '\uD83D\uDCB0'], [166, '\uD83D\uDC8D'], [168, '\uD83D\uDC99'],
      [170, '\uD83C\uDF81'], [171, '\uD83C\uDF89'], [172, '\uD83C\uDF88'],
      [173, '\uD83C\uDF8A'], [174, '\uD83C\uDF8D'], [175, '\uD83D\uDC4D'],
      [176, '\uD83D\uDC4E'], [177, '\uD83D\uDC4C'], [178, '\uD83D\uDC4F'],
      [179, '\uD83D\uDC4F'], [180, '\u2615'], [181, '\uD83C\uDF7A'],
      [182, '\uD83C\uDF7B'], [183, '\uD83C\uDF78'], [184, '\uD83C\uDF79'],
      [185, '\uD83C\uDF76'], [186, '\uD83C\uDF7D'], [187, '\uD83C\uDF69'],
      [188, '\uD83C\uDF82'], [190, '\uD83C\uDF1D'], [191, '\uD83D\uDE0F'],
      [192, '\uD83E\uDD14'], [193, '\uD83D\uDE0F'], [194, '\uD83D\uDE0F'],
      [200, '\uD83C\uDF89'], [201, '\uD83C\uDF89'], [202, '\uD83C\uDF89'],
      [203, '\uD83D\uDC4D'], [204, '\uD83D\uDC4E'], [205, '\uD83D\uDC4F'],
      [210, '\uD83D\uDC4B'], [211, '\uD83D\uDC4B'], [212, '\uD83D\uDC4B'],
      [213, '\uD83D\uDC4B'], [214, '\uD83D\uDC4B'], [220, '\uD83C\uDF1E'],
      [260, '\uD83D\uDC4D'], [261, '\uD83D\uDC4E'], [262, '\uD83D\uDC4F'],
      [263, '\uD83D\uDC4B'], [264, '\uD83D\uDC4B'], [265, '\uD83D\uDC4B'],
      [311, '\uD83D\uDE02'], [312, '\uD83D\uDE2D'],
    ];
    for (let p of pairs) {
      FaceStore.map.set(p[0], p[1]);
    }
  }

  static getFace(faceId: number): string {
    return FaceStore.map.get(faceId) || '';
  }

  static hasFace(faceId: number): boolean {
    return FaceStore.map.has(faceId);
  }
}

FaceStore.init();
