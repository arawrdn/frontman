import { CMS_NAME } from "@/lib/constants";

export function Intro() {
  return (
    <section className="flex-col md:flex-row flex items-center md:justify-between mt-16 mb-16 md:mb-12">
      <h1 className="text-5xl md:text-8xl font-bold tracking-tighter leading-tight md:pr-8">
        Jedi Archives.
      </h1>
      <h4 className="text-center md:text-left text-lg mt-5 md:pl-8">
        A long time ago in a galaxy far, far away... this holonet transmission was statically generated using{" "}
        <a
          href="https://nextjs.org/"
          className="underline hover:text-yellow-400 duration-200 transition-colors"
        >
          Next.js
        </a>{" "}
        and {CMS_NAME}. May the Force be with you, young Padawan.
      </h4>
    </section>
  );
}
