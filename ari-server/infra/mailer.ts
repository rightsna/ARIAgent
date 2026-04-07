import handlebars from "handlebars";
import { fileExistsSync, readTextSync } from "./data.js";
import path from "path";
import nodemailer from "nodemailer";
import { logger } from "./logger.js";
import { resolveServerPath } from "./runtime_paths.js";

export namespace Mailer {
  export const sendMail = async (email: string, htmlfile: string, title: string, replacements: any) => {
    // 수신자 이메일 검증: 빈 값이면 예외 처리
    if (!email || email.trim() === "") {
      throw new Error("수신자 이메일이 정의되지 않았습니다.");
    }

    const filePath = [
      resolveServerPath("infra", htmlfile),
      resolveServerPath("template", htmlfile),
      path.join(process.cwd(), "infra", htmlfile),
      path.join(process.cwd(), "template", htmlfile),
      path.join(process.cwd(), "ari-server", "infra", htmlfile),
      path.join(process.cwd(), "ari-server", "template", htmlfile),
    ].find((candidate) => fileExistsSync(candidate)) ?? resolveServerPath("infra", htmlfile);
    const source = readTextSync(filePath);
    const template = handlebars.compile(source);
    const htmlToSend = template(replacements);

    const transporter = nodemailer.createTransport({
      service: "naver",
      host: process.env.NODEMAILER_HOST,
      port: Number(process.env.NODEMAILER_PORT),
      secure: false,
      auth: {
        user: process.env.NODEMAILER_USER,
        pass: process.env.NODEMAILER_PASS,
      },
    });

    const mailOptions = {
      from: `"${process.env.COMPANYNAME} Team" <${process.env.NODEMAILER_USER}>`,
      to: email,
      subject: title,
      html: `<b>${htmlToSend}</b>`,
    };

    try {
      const info = await transporter.sendMail(mailOptions);
      // info를 필요에 따라 활용 가능
    } catch (error) {
      logger.error("Error sendMail:", error);
      throw error;
    }
  };

  export const send = async (email: string, title: string, text: string) => {
    const transporter = nodemailer.createTransport({
      service: "naver",
      host: process.env.NODEMAILER_HOST,
      port: Number(process.env.NODEMAILER_PORT),
      secure: false,
      auth: {
        user: process.env.NODEMAILER_USER,
        pass: process.env.NODEMAILER_PASS,
      },
    });

    try {
      const info = await transporter.sendMail({
        from: `"${process.env.COMPANYNAME} Team" <${process.env.NODEMAILER_USER}>`,
        to: email,
        subject: title,
        html: `<b>${text}</b>`,
      });
      // info를 필요에 따라 활용 가능
    } catch (error) {
      logger.error("Error send mail:", error);
      throw error;
    }
  };

  // 에러 발생 시 에러 정보를 이메일로 전송하는 함수
  export const sendErrorEmail = async (error: Error) => {
    const errorRecipient = process.env.ERROR_EMAIL;
    if (!errorRecipient) {
      logger.error("ERROR_EMAIL 환경변수가 설정되어 있지 않습니다.");
      return;
    }
    // 제목과 본문 구성
    const subject = `${process.env.COMPANYNAME || "Server"} Error Alert`;
    const text = `Error Message: ${error.message}\n\nStack Trace:\n${error.stack}`;

    try {
      await send(errorRecipient, subject, text);
    } catch (err) {
      logger.error("Failed to send error email:", err);
    }
  };
}
