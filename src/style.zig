const dvui = @import("dvui");

const Color = dvui.Color;
const Font = dvui.Font;
const Theme = dvui.Theme;
const bitstream_vera = dvui.bitstream_vera;

const accent = Color{ .r = 0, .g = 129, .b = 112 }; //Color{ .r = 0xa0, .g = 0xe7, .b = 0xe5, .a = 210 };
const success = Color{ .r = 0xb4, .g = 0xf8, .b = 0xc8, .a = 210 };
const err = Color{ .r = 204, .g = 2, .b = 2 };
const control = Color{ .r = 0, .g = 91, .b = 65 };

const dark_fill = Color.transparent(Color{ .r = 0x1e, .g = 0x1e, .b = 0x1e }, 0.8);

pub var keypass_light = Theme{
    .name = "KeypassLight",
    .dark = true,

    .font_body = Font{ .size = 11, .name = "Vera", .ttf_bytes = bitstream_vera.Vera },
    .font_heading = Font{ .size = 11, .name = "VeraBd", .ttf_bytes = bitstream_vera.VeraBd },
    .font_caption = Font{ .size = 9, .name = "Vera", .ttf_bytes = bitstream_vera.Vera },
    .font_caption_heading = Font{ .size = 9, .name = "VeraBd", .ttf_bytes = bitstream_vera.VeraBd },
    .font_title = Font{ .size = 24, .name = "Vera", .ttf_bytes = bitstream_vera.Vera },
    .font_title_1 = Font{ .size = 20, .name = "VeraBd", .ttf_bytes = bitstream_vera.VeraBd },
    .font_title_2 = Font{ .size = 17, .name = "VeraBd", .ttf_bytes = bitstream_vera.VeraBd },
    .font_title_3 = Font{ .size = 15, .name = "VeraBd", .ttf_bytes = bitstream_vera.VeraBd },
    .font_title_4 = Font{ .size = 13, .name = "VeraBd", .ttf_bytes = bitstream_vera.VeraBd },

    .style_content = .{
        .accent = accent,
        .text = Color.white,
        .fill = dark_fill,
        .border = Color.lerp(control, 0.4, Color.white),
        .hover = Color.lerp(control, 0.2, Color.white),
        .press = Color.lerp(control, 0.3, Color.white),
    },

    .style_control = .{
        .accent = control.lighten(0.3),
        //.text = Color.white,
        .fill = control,
        .border = Color.lerp(control, 0.4, Color.black),
        .hover = Color.lerp(control, 0.2, Color.black),
        .press = Color.lerp(control, 0.3, Color.black),
    },
    .style_window = .{ .fill = Color{ .r = 35, .g = 45, .b = 63 } },

    .style_accent = .{
        .accent = accent.darken(0.3),
        .fill = accent,
        //.text = Color.white,
        .border = Color.lerp(accent, 0.4, Color.white),
        .hover = Color.lerp(accent, 0.2, Color.white),
        .press = Color.lerp(accent, 0.3, Color.white),
    },
    .style_success = .{
        .accent = success.darken(0.3),
        .fill = success,
        .text = Color.white,
        .border = Color.lerp(success, 0.4, Color.white),
        .hover = Color.lerp(success, 0.2, Color.white),
        .press = Color.lerp(success, 0.3, Color.white),
    },
    .style_err = .{
        .accent = err.darken(0.3),
        .fill = err,
        .text = Color.white,
        .border = Color.lerp(err, 0.4, Color.white),
        .hover = Color.lerp(err, 0.2, Color.white),
        .press = Color.lerp(err, 0.3, Color.white),
    },
};
